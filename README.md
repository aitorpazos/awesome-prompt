# awesome-prompt
This script provides an easy way to enjoy a colorful responsive prompt.
It divides the prompt line in three sections: left, center and right. If they don't fit, it will move those sections that doesn't fit to the next line.

## Instructions:
 In order to use this script using the default config, you just need to add this line to your $HOME/.bashrc file:
    `source <full path to the script>`
 You can modify shown information using environment variables that you can export before sourcing the line in the previous point or while running for temporary modifications:
 ```
 export <option>=1
 ```
 Supported options:
 * `SHOW_BAT_STATUS`: Shows the battery charge and if you are running on AC or battery 
 * `SHOW_SYS_STATS`: Shows the most CPU consuming process at the moment
 * `SHOW_QEMU`: Shows currently running Qemu VMs. Beware of it's performance impact.
 * `SHOW_VBOX`: Shows currently running VirtualBox VMs. Beware of it's performance impact.
 * `SHOW_GIT`: Shows GIT information of current working directory. It requires `git-prompt.sh` script ( which is part of Git distribution and possibly at `/etc/bash_completion.d/git-prompt.sh` ) has been sourced before this script. i.e.:
 ```
 source $HOME/.git-prompt.sh
 export SHOW_GIT=1
 source $HOME/awesome-prompt.sh
```
 * `SHOW_TIMING`: Only for debug purposes. It prints timing information to stderr in order to help spotting commands that might slow the prompt.

 Copyright (C) 2016 Aitor Pazos <mail@aitorpazos.es>
 
 Distributed under the GNU General Public License, version 3.0.
