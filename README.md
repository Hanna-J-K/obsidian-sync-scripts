This is:
- a simple bash script for automatically pushing changes in an Obsidian Vault to associated GitHub repo
- a plint file for a LaunchAgent scheduled sync on macOS

This assumes:
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
