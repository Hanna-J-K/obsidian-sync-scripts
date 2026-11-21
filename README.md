## What is it
This is a simple `bash` script for automatically pushing changes in an Obsidian Vault to associated GitHub repo. Plus a `plint` file for a LaunchAgent scheduled sync on macOS.

It assumes:
- Github CLI is used for authentication
- the GitHub account you're planning on using already has login credentials saved locally (e.g. you've logged manually at least once)
- the remote you're using for the Obsidian vault already exists (i.e. the repo for it has been created)

## How to
Once you have downloaded the `obsidian-sync-example.sh` file, edit the configuration inside with required info:
- `VAULT`: absolute path to your local Obsidian vault
- `PERSONAL_GH_USER`: your GitHub username (e.g. `"Hanna-J-K"`)
- `BRANCH`: by default it's `main` but change it if you want to operate on a differently-named branch in your GitHub repo
- `EXPECTED_REMOTE`: url to your Obsidian vault GitHub repository (e.g. `"https://github.com/Hanna-J-K/obsidian-sync-scripts.git"`)

If you want, you can also change how `PATH` is exported (it's all rather straightforward). The script does not intercept or store any credentials, it just triggers `gh` commands to ensure a proper account is used for commits, pulling and pushing.

Once it's ready, you can manually run the script (you may need to add execute permissions with `chmod 700`). 

### LaunchAgent
Once you have downloaded the `plint` file, place it in `~/Library/LaunchAgents`. Then edit the file with appropriate values:
- `Label`: only change its string value if you have renamed the file
- `ProgramArguments`: edit the path to your `bash` script; note that the file expects a specific path format (starting with `/Users/`)
- `RunAtLoad`: will run the script at the start of service (without interval); can be removed if you wish
- `StartInterval`: by default the service will check for changes every 15mins (900s); change the value to change the interval
- `StandardOutPath` and `StandardErrorPath`: outputs for logs and error logs, edit with your macOS username

Assuming you've made all the required edits, you can then validate the `plint` file (replace with actual path and filename):

`plutil -lint "$HOME/Library/LaunchAgents/com.user.obsidian-sync-example.plist"`

Register the service:

`launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.user.obsidian-sync-example.plist"`

The service should now run. You can check the status with `launchctl print "gui/$(id -u)/com.user.obsidian-sync-example"`; look for `state`, `runs` and `last exit code` to ensure everything fired up properly.

Note that the service won't run if the system is sleeping, but upon restart and login macOS will usually load the installed LaunchAgent again.

To stop and unload the service, run `launchctl bootout "gui/$(id -u)/com.user.obsidian-sync-example"`. Note that any changes to `plist` file (such as changing the interval) requires unloading and starting the service up again for them to take effect.
