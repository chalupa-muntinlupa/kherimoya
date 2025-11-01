<div align="center">
  <img src="images/kherimoyasingle665.png" alt="kherimoya" width="300"/> <img src="images/kherimoya.png" alt="kherimoyafolder" width="90"/>

  <small>/kɛrɪˈmoʊjə/ care-ih-moh-ya</small>

# kherimoya - server manager through [endstone](https://github.com/EndstoneMC/endstone)
</div>

> [!WARNING]
> This version of Kherimoya is **unfinished and does not work as of now**.
>
> This is the version where I upgrade the scripts, and right now it's unfinished.

## introduction
Kherimoya *(right now)* does not do much. For now, Kherimoya only sets up a "kherimoya" environment that is just a folder set up with Endstone.

Kherimoya is very early in its development, and right now is only good for managing multiple servers, and right now isn't very good compared to just using Endstone.

## kheremara
Kheremara is an umbrella identity used for things like plugins *(just plugins right now)* that utilize Kherimoya's features like its file structure

## features

## planned features
The following features **WILL** be included in Kherimoya in the future.
<ul>
    <li>Kherimoya endstone plugin, that can do things like tell the status of the server and communicate with Kherimoya
    <li>Move to python instead of shell
    <li>Better scripts, ones that do not rely on a project path declared in the scripts
    <li>More features like server status, discord bot, etc... (discord bot may just become extension)
    <li>Automatic server backups
</ul>
The following features <strong>MAY</strong> be includeded in Kherimoya in the future
<ul>
    <li>Extensions
    <li>Custom API for plugins
    <li>Windows compatability
</ul>

## setup

### Linux instructions
1. Clone the repo
    ```bash
    git clone https://github.com/chalupa-muntinlupa/kherimoya
    ```
2. Go in each script, and change the MARA_PATH= & PROJECT_PATH=. MARA_PATH is the path to a directory which has a python env called "maraenv" that has Endstone installed, and PROJECT_PATH is the location of Kherimoya's root. *(This step will no longer be needed in Kherimoya's next update, where we upgrade our scripts)*
   
...And that's it! Please don't install this, it's not ready for actual use right now.

