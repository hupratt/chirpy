---
title: Productivity on gnu/linux
author: hugo
date: 2025-05-29 09:11:00 +0200
categories: [Blogging]
tags: [sysadmin, linux]
render_with_liquid: false
---

## Introduction

I've spent long hours studying and refreshing my knowledge of linux in the past months so I feel I need to lighten up the atmosphere a bit and turn down the technical complexity. This article focuses on productivity with linux by going over my configuration and the tools I use to speed up my daily tasks.


### 1. Command line: Zsh
  
  I've added fuzzy history finder ```fzf``` to my ```.zshrc``` so that I can find a previous command quickly. 

  zsh (ohmyzsh package) also has tons of plugins for autocompletion. Some popular ones i'm using: 

  - git
  - dnf
  - zsh-autosuggestions
  - zsh-syntax-highlighting

  but there are of hundreds available. Look at your favorite tool like ```kubectl``` and see if it has a corresponding zsh plugin. 

  ![posthog](/assets/img/posts/ohmyzsh.jpg){: width="100%"}

### 2. Vscode
  
  I mostly use my text editor for web development, scripting and writing markdown. Vscode and its shortcuts for easy text manipulation and editing is the ideal tool for me right now. I know that neovim is a big contender in this space but i'm not ready to dig that rabbithole just yet. Nor do I need to.

  I have some custom bindings to override the custom vscode key binds. You can save this json in any vscode project under .vscode/keybindings.json

  ```json
  [
      {
          "key": "alt+right",
          "command": "workbench.action.navigateForward"
      },
      {
          "key": "alt+left",
          "command": "workbench.action.navigateBack"
      },
      {
          "key": "ctrl+shift+down",
          "command": "-editor.action.copyLinesDownAction",
          "when": "editorTextFocus && !editorReadonly"
      },
      {
          "key": "ctrl+k",
          "command": "editor.action.deleteLines",
          "when": "textInputFocus && !editorReadonly"
      },
      {
          "key": "ctrl+shift+k",
          "command": "-editor.action.deleteLines",
          "when": "textInputFocus && !editorReadonly"
      }
  ]
  ```

  Add breakpoints to your python code in vscode with this json configuration file. There are some good ones you can use for django as well. You can save this json in any vscode project under .vscode/launch.json

  ```json
  {
      // Use IntelliSense to learn about possible attributes.
      // Hover to view descriptions of existing attributes.
      // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
      "version": "0.2.0",
      "configurations": [

          {
              "name": "Brevo",
              "type": "debugpy",
              "request": "launch",
              "program": "${file}",
              "python": "${workspaceFolder}/brevo/env/bin/python",
              "console": "integratedTerminal"
          },
          {
              "name": "supersecretproject",
              "type": "debugpy",
              "request": "launch",
              "program": "${file}",
              "python": "${workspaceFolder}/Scripting/python/supersecretproject/env/bin/python",
              "console": "integratedTerminal"
          }
      ]
  }
  ```

  ![keybinds](/assets/img/posts/keybinds.gif){: width="100%"}

### 3. Window manager
  
  X11 is not officially discontinued but it is being phased out in favor of Wayland. So I naturally gravitated towards Wayland and hyprland for my desktop/window manager

  ![keybinds](/assets/img/posts/hyprland.gif){: width="100%"}

### 4. Clipboard history
  
  I use a small bash script that calls the ```cliphist list``` command and the rofi menu to display them as a pop up
  
  ```bash
  #!/bin/bash
  # /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
  # Clipboard Manager. This script uses cliphist, rofi, and wl-copy.

  # Variables
  rofi_theme="$HOME/.config/rofi/config-clipboard.rasi"
  msg='👀 **note**  CTRL DEL = cliphist del (entry)   or   ALT DEL - cliphist wipe (all)'
  # Actions:
  # CTRL Del to delete an entry
  # ALT Del to wipe clipboard contents

  # Check if rofi is already running
  if pidof rofi > /dev/null; then
    pkill rofi
  fi

  while true; do
      result=$(
          rofi -i -dmenu \
              -kb-custom-1 "Control-Delete" \
              -kb-custom-2 "Alt-Delete" \
              -config $rofi_theme < <(cliphist list) \
        -mesg "$msg" 
      )

      case "$?" in
          1)
              exit
              ;;
          0)
              case "$result" in
                  "")
                      continue
                      ;;
                  *)
                      cliphist decode <<<"$result" | wl-copy
                      exit
                      ;;
              esac
              ;;
          10)
              cliphist delete <<<"$result"
              ;;
          11)
              cliphist wipe
              ;;
      esac
  done
  ```

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://minio-api.thekor.eu/chirpy-videos-f1492f08-f236-4a55-afb7-70ded209cb28/chirpy/clipboard.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

### 5. Thunderbird
  
  Simply installing the desktop and mobile versions of the app brought me significant improvements to my calendar, email and contacts syncronization. Make sure you're using imaps so that once you read an email on one device marks them as read on all other devices. I haven't found a way to sync calendar and contacts on mobile because thunderbird does not support ir for now but it's not a "nice to have" feature so I guess I'll just do without it.

  ![keybinds](/assets/img/posts/thunderbird.gif){: width="100%"}

### 6. Swaync
  
  Having a notification center that allows you to control your music paired with a keyboard with media controls is an absolute must for me. You can also allow certain web applications that have PWA capabilities to send notifications to that pannel. Everything is handled for you by the browser so if these concepts seem foreign to you don't worry. Everything is already handled by your internet browser. 

  ![keybinds](/assets/img/posts/swaync.gif){: width="100%"}


### 7. Tmux: sharing terminals with co-workers
  
  Tmux is an absolute must have. You can also use it to keep background tasks running as I often forget about them and accidentally close the windows. If for instance you need to give root access to a coworker who does not have those permissions you can temporarily open a shell for him on a jump server. 


  It's also extremely useful for coworkers to show something on the terminal without having to start a screen share over teams, slack or zoom. 

  ![keybinds](/assets/img/posts/tmux.gif){: width="100%"}
