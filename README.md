my dotfiles :)

Home Manager imports `nix/home.nix` to link every entry in `.config` and every
home dotfile in this repository from the editable checkout at `~/.dot`.
Repository metadata and `.config` itself are excluded from the home-level links.
It also creates `.zshenv` with the same settings as `run_me.sh` and adds the user
binary and script directories to PATH. Newly committed configs are included
automatically. The caller supplies the Home Manager username,
home directory and state version. Config files remain in their original formats;
`run_me.sh` is still available for installation on other platforms.
```
                                           ▄▄▄▄▄▄▄▄                            
                                      ▄▄██████████████▄▄                       
                                   ▄██████████████████████▄                    
                                 ▄██████████████████████████▄                  
                               ▄█▀▄████████████████████████▄▀█▄                
                              ▄█  ██████████████████████████  █▄               
                             ▄█▀ ▄██████████████████████████▄ ▀█▄              
                             █▀  ████████████████████████████  ▀█              
                               ▄██████████████████████████████▄                
                             ████████████████████████████████████              
                             ████████████████████████████████████              
                             ▀██▀  ▀▀████████████████████▀▀  ▀██▀              
                              ██       ▀██▀████████▀██▀       ██               
                               ██        ▀█ ██████ █▀        ██                
                                ██▄        █ ████ █        ▄██                 
                                 ███▄▄▄▄    █ ██ █    ▄▄▄▄███                  
                                  ▀▀▀▀▀████▄██████▄████▀▀▀▀▀                   
                                    ██▄ █████▄██▄█████ ▄██                     
                                     ██▄ ████████████ ▄██                      
                                      ▀█████▀▄▄▄▄▀█████▀                       
                                        ▀▀██████████▀▀                         
                                           ▀██████▀                            

              █                                                 █ █            
              █▀▀▀▀▀▀▀▀▀█ █▀▀▀▀▀▀▀▀▀▀ █▀▀▀▀▀▀▀▀▀█ █▀▀▀▀▀▀▀▀▀▀ █ █ █ ▀▀▀▀▀▀▀▀▀▀█
              █         █ █           █▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀█ █ █ █ █▀▀▀▀▀▀▀▀▀█
              ▀▀▀▀▀▀▀▀▀▀▀ ▀           ▀▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀▀ ▀ ▀ ▀ ▀▀▀▀▀▀▀▀▀▀▀
```

wallpapers: (https://www.patreon.com/kvacm)

![Imgur](https://i.imgur.com/sZLcsGl.png)
![Imgur](https://i.imgur.com/hpB3OVf.jpg)
![Imgur](https://i.imgur.com/Rr9kF7T.jpg)
![Imgur](https://i.imgur.com/Qicamy4.jpg)
![Imgur](https://i.imgur.com/8plCq37.png)
![Imgur](https://i.imgur.com/7DXwNP2.png)
![Imgur](https://i.imgur.com/T600o36.jpg)
![Imgur](https://i.imgur.com/p0t01YM.jpg)
![Imgur](https://i.imgur.com/d9ZeRCM.png)
![Imgur](https://i.imgur.com/x7eAEgz.png)
![Imgur](https://i.imgur.com/8WP5bwN.jpg)
![Imgur](https://i.imgur.com/EbZlMdp.jpg)
