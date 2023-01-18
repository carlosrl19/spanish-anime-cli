# Spanish Anime CLI
<div align="center">
  <h1>Spanish Anime-cli</h1>
 </div>

## What it's about

Spanish Anime CLI is a commandline app created using bash to watch sub-spanish / latin anime from a linux terminal client. 

It's depends to mpv, grep, sed & curl , so you have to install it.

Debian / Ubuntu based distros:
```bash
  sudo apt install mpv grep sed curl
```
Arch based distros:
```bash
  sudo pacman -S mpv grep sed curl
```

## Usage

First you have downloaded the app, then you can run anime-cli in your terminal:
```bash
  ./hani-cli <anime-name>
```

For example:

```bash
  ./hani-cli Naruto
```

Enter the name of the anime you want to search for, if there is any similar search result, then it will be displayed in an enumerated list as shown below:

![image](https://user-images.githubusercontent.com/85375012/212786589-c86a0956-ff4e-497a-92e9-739022e102b2.png)
