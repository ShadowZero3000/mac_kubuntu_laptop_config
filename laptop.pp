
define download_package_install(
  $installer,
  $source,
  $package_name = $title,
) {
  archive{"/opt/installers/${installer}":
    ensure  => present,
    extract => false,
    source  => $source,
  }->
  package{$package_name:
    ensure => present,
    provider => dpkg,
    source => "/opt/installers/${installer}",
  }
}

###################################################################
# Pre-requisites and variables
###################################################################
file{'/opt/installers':
  ensure => directory,
}

$username = 'jsouza'
$home = "/home/${username}"


package{['gvfs-bin','libgnome-keyring-dev']:
  ensure => present,
  before => Package['slack-desktop'],
}

package{['mono-complete','php-cli', 'php-mbstring', 'php-mcrypt']:
  ensure => present,
  before => Package['keepass2'],
}
###################################################################
# My folder structures
###################################################################

file{["${home}/workspace","${home}/workspace/puppet"]:
  ensure => directory,
}

###################################################################
# Packages for software I want
###################################################################

#Available sublime module sucks, ignoring
$package_details={
  'slack-desktop' => {
    'installer' => 'slack.deb',
    'source' => 'https://downloads.slack-edge.com/linux_releases/slack-desktop-2.0.6-amd64.deb',
  },
  'sublime-text' => {
    'installer' => 'sublime.deb',
    'source' => 'https://download.sublimetext.com/sublime-text_build-3114_amd64.deb',
  },
  'smartgit' => {
    'installer' => 'smartgit.deb',
    'source' => 'http://www.syntevo.com/static/smart/download/smartgit/smartgit-7_1_3.deb',
  },
  'gitkraken' => {
    'installer' => 'gitkraken.deb',
    'source' => 'https://release.gitkraken.com/linux/gitkraken-amd64.deb',
  }
}

create_resources(download_package_install,$package_details)

###################################################################
# Configuration of Sublime Text
###################################################################
file { "${home}/.config/sublime-text-3":
  ensure => directory,
} 
file { "${home}/.config/sublime-text-3/Packages": 
  ensure => directory,
  require => Package["sublime-text"],
} ->
file { "${home}/.config/sublime-text-3/Packages/User": ensure => directory, } ->
file { "${home}/.config/sublime-text-3/Packages/User/Default (Linux).sublime-mousemap":
    ensure => present,
    content => '[
    // Mouse 3 column select
    {
        "button": "button3",
        "press_command": "drag_select",
        "press_args": {"by": "columns"}
    },
    {
        "button": "button3", "modifiers": ["ctrl"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "additive": true}
    },
    {
        "button": "button3", "modifiers": ["alt"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "subtractive": true}
    }
    ]',
    #source => "puppet:///modules/sublime/${::kernel}/config",
    mode   => '0644',
    owner  => $username,
    group  => $username,
  }



###################################################################
# Modules that provide software out of the box
###################################################################
include '::vagrant'
include '::google_chrome'
include '::rbenv'
include '::ohmyzsh'
include '::virtualbox'
include '::dropbox'


###################################################################
# Packages available in core repositories
###################################################################
package{[
  'terminator',
  'autokey-gtk',
  'keepass2',
  'powerline',
  ]:
  ensure => present,
}

###################################################################
# Fonts
###################################################################
file{'/usr/local/share/fonts/truetype':
  ensure => directory,
}
file{'/usr/local/share/fonts/truetype/hackfont':
  ensure => directory,
} ->
archive{'/opt/installers/hackfont.zip':
  ensure => present,
  source => 'https://github.com/chrissimpkins/Hack/releases/download/v2.020/Hack-v2_020-ttf.zip',
  extract => true,
  extract_path => '/usr/local/share/fonts/truetype/hackfont',
  creates => '/usr/local/share/fonts/truetype/hackfont/Hack-Regular.ttf'
} ~>
exec{'refresh font cache':
  command => 'fc-cache',
  path => '/usr/bin',
  refreshonly => true,
}

###################################################################
# Ruby
###################################################################
rbenv::plugin { 'sstephenson/ruby-build': }
rbenv::build{'2.2.3': 
  global => true,
}
file{'/usr/local/bin/rbenv':
  target => '/usr/local/rbenv/bin/rbenv',
  require => Class['rbenv'],
}

###################################################################
# Zsh config
###################################################################
# for multiple users in one shot
ohmyzsh::install { ['root', $username]: }
ohmyzsh::theme { ['root', $username]: 
  theme => 'agnoster' 
} # specific theme
file_line{'add powerline':
  path => "${home}/.zshrc",
  line => 'source /usr/share/powerline/bindings/zsh/powerline.zsh',
  after => 'source $ZSH/oh-my-zsh.sh',
}
file_line{'zsh_rbenv_root':
  path => "${home}/.zshrc",
  line => 'export RBENV_ROOT=/usr/local/rbenv',
}
file_line{'zsh_rbenv_path':
  path => "${home}/.zshrc",
  line => 'export PATH="$RBENV_ROOT/bin:$PATH"',
  after => 'export RBENV_ROOT=/usr/local/rbenv',
}
file_line{'zsh_rbenv_init':
  path => "${home}/.zshrc",
  line => 'eval "$(rbenv init -)"',
  after => 'export PATH="$RBENV_ROOT/bin:$PATH"',
}
file_line{'zsh_bundle_exec_rake':
  path => "${home}/.zshrc",
  line => 'alias ber="noglob bundle exec rake"',
}

#file_line{'docker-machine':
#  path => "${home}/.zshrc",
#  line => 'eval "$(docker-machine env default)"'
#}


###################################################################
# Node.JS and modules
###################################################################
class{'::nodejs':
  version => 'stable',
  make_install => false,
}
package{['yo','generator-puppetskel']:
  provider => 'npm',
}

###################################################################
# Docker
###################################################################
class { 'docker':
  manage_kernel => false,
}

###################################################################
# Install KeePassHTTP
###################################################################
wget::fetch { 'download keepasshttp':
  source => 'https://raw.github.com/pfn/keepasshttp/master/KeePassHttp.plgx',
  destination => '/usr/lib/keepass2/',
  mode => '0644',
  require => Package['keepass2'],
}

###################################################################
# Screencloud
###################################################################

apt::key { 'screencloud':
  id => '53C297DBF366CF7DEEB5ABF81BE1E8D7A2B5E9D5',
  source => 'http://download.opensuse.org/repositories/home:olav-st/xUbuntu_16.04/Release.key',
}->
apt::source { 'screencloud':
  comment => 'This is for installing ScreenCloud',
  location => 'http://download.opensuse.org/repositories/home:/olav-st/xUbuntu_16.04/',
  release => '/',
  repos => '',
}->
package{'screencloud':}
###################################################################
# Correct caps lock to be tab
###################################################################
file{"${home}/.Xmodmap":
  ensure => present,
} ~>
exec{"map_caps_to_tab":
  refreshonly => true,
  command => '/usr/bin/xmodmap -e "keycode 66 = Tab"',
} ~>
exec{"update_keymap":
  refreshonly => true,
  command => "/usr/bin/xmodmap -pke > ${home}/.Xmodmap",
}
file{"${home}/.xinitrc":
  content => "xmodmap ~/.Xmodmap",
  owner   => $username,
  mode    => '0644'
}

###################################################################
# Autokey scripts + keepass integration
###################################################################
$autokey_keepass_template = @(END)
key = '<%= $keepass_key %>'
clipass_path = '<%= $clipass_path %>'
output = system.exec_command("echo `php "+clipass_path+" --key='"+key+"'`")
keyboard.send_keys(output)
END

$autokey_phrase = @(END)
{
    "usageCount": 2, 
    "omitTrigger": false, 
    "prompt": false, 
    "description": "<%= $name %>", 
    "abbreviation": {
        "wordChars": "[\\w]", 
        "abbreviations": [], 
        "immediate": false, 
        "ignoreCase": false, 
        "backspace": true, 
        "triggerInside": false
    }, 
    "hotkey": {
        "hotKey": "<%= $hotkey %>", 
        "modifiers": [
            "<super>"
        ]
    }, 
    "modes": [
        3
    ], 
    "showInTrayMenu": false, 
    "matchCase": false, 
    "filter": {
        "regex": null, 
        "isRecursive": false
    }, 
    "type": "phrase", 
    "sendMode": "kb"
}
END

$autokey_script = @(END)
{
    "usageCount": 0, 
    "omitTrigger": false, 
    "prompt": false, 
    "description": "<%= $name %>", 
    "abbreviation": {
        "wordChars": "[\\w]", 
        "abbreviations": [], 
        "immediate": false, 
        "ignoreCase": false, 
        "backspace": true, 
        "triggerInside": false
    }, 
    "hotkey": {
        "hotKey": "<%= $hotkey %>", 
        "modifiers": [
            "<super>"
        ]
    }, 
    "modes": [
        3
    ], 
    "showInTrayMenu": false, 
    "filter": {
        "regex": null, 
        "isRecursive": false
    }, 
    "type": "script", 
    "store": {}
}
END

$autokey_folder = @(END)
{
    "usageCount": 0, 
    "abbreviation": {
        "wordChars": "[\\w]", 
        "abbreviations": [], 
        "immediate": false, 
        "ignoreCase": false, 
        "backspace": true, 
        "triggerInside": false
    }, 
    "modes": [], 
    "title": "<%= $name %>", 
    "hotkey": {
        "hotKey": null, 
        "modifiers": []
    }, 
    "filter": {
        "regex": null, 
        "isRecursive": false
    }, 
    "type": "folder", 
    "showInTrayMenu": false
}
END

file{"${home}/workspace/keepass":
  ensure => directory,
}

$clipass_root = "${home}/workspace/keepass/clipass"
$clipass_path = "${clipass_root}/clipass.php"

file { "${home}/AK Scripts":
  ensure => directory,
  owner  => $username,
  group  => $username,
}
file { "${home}/AK Scripts/.folder.json":
  ensure  => file,
  content => inline_epp($autokey_folder, {'name' => 'AK Scripts'}),
  owner  => $username,
  group  => $username,
}
file { "${home}/AK Scripts/pw-pk.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'ProKarma'}),
  owner  => $username,
  group  => $username,
}
file { "${home}/AK Scripts/.pw-pk.json":
  ensure  => file,
  content => inline_epp($autokey_script, {'name' => 'pw-pk', 'hotkey' => 'p'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/pw-tmo1.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'T-Mobile NTid'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/.pw-tmo1.json":
  ensure  => file,
  content => inline_epp($autokey_script, {'name' => 'pw-tmo1', 'hotkey' => 'o'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/pw-tmo2.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'T-Mobile two'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/.pw-tmo2.json":
  ensure  => file,
  content => inline_epp($autokey_script, {'name' => 'pw-tmo2', 'hotkey' => 'i'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/Email.txt":
  ensure  => file,
  content => '@prokarma.com',
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/.Email.json":
  ensure  => file,
  content => inline_epp($autokey_phrase, {'name' => 'Email', 'hotkey' => 'e'}),
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/Username.txt":
  ensure  => file,
  content => 'jsouza',
  owner   => $username,
  group   => $username,
}
file { "${home}/AK Scripts/.Username.json":
  ensure  => file,
  content => inline_epp($autokey_phrase, {'name' => 'Username', 'hotkey' => 'j'}),
  owner   => $username,
  group   => $username,
}

# CliPass
$composer_template = @(END)
#!/bin/bash
hash="e115a8dc7871f15d853148a7fbac7da27d6c0030b848d9b3dc09e2a0388afed865e6a3d6b3c0fad45c48e2b5fc1196ae"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('SHA384', 'composer-setup.php') === '${hash}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
END

vcsrepo{$clipass_root:
  ensure => present,
  provider => 'git',
  source => 'https://github.com/bartlomiej-dudala/clipass.git',
  user => $username,
} -> 
file{"${clipass_root}/get_composer.sh":
  content => inline_epp($composer_template),
  mode => '0755',
  owner => $username,
} ->
exec{"install_composer":
  user => $username,
  environment => ["HOME=/home/${username}"],
  logoutput => true,
  cwd => $clipass_root,
  command => "/bin/bash ./get_composer.sh",
  creates => "${clipass_root}/composer.phar",
} -> 
exec{"install clipass":
  user => $username,
  environment => ["HOME=/home/${username}"],
  cwd => $clipass_root,
  command => "/usr/bin/php composer.phar install",
  # This is wrong, I just don't know what is correct
  creates => "${clipass_root}/vendor/autoload.php",
}
notice("You may need to run the composer stuff in ${clipass_root} manually?")
