# silence script
exec 3>&1 4>&2 1>/dev/null 2>&1

repo="$(git config remote.origin.url)"
baseUrl=${repo%%/repos*}
anglerUrl="$baseUrl/hooks"

git config angler.url "$anglerUrl"
gitroot="$(git rev-parse --show-toplevel)"

curl -sfH "X-GitStream-Repo: $repo" "$baseUrl/go"
if [ $? != 0 ]; then >&4 echo 'GitStream: Unable to connect to server.'; exit 1; fi

# remove hooks to prevent the following from triggering events
rm "$gitroot"/.git/hooks/*

# remove added remotes and refs
git remote | grep -v "^origin$" | xargs -L 1 git remote remove
git remote prune origin
git show-ref --tags --heads | grep -v "/master$" | cut -d" " -f 2 | xargs -L 1 git update-ref -d

# move back to master, clean up the sandbox, and reset to origin state
git checkout -f master
git reset --hard HEAD
git clean -df
git fetch origin
git reset --hard origin/master

# remove unnecessary blobs
git reflog expire --expire=now --all
git gc --prune=now

# run the setup script, if one is provided
"$gitroot"/.gitstream/setup.sh

# reinstate the hooks
cp "$gitroot"/.gitstream/hooks/* "$gitroot"/.git/hooks/

# let the user know that everything went well
>&3 echo "GitStream: Follow the instructions in your browser!"
