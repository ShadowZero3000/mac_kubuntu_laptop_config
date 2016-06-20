
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

$username = 'josh'
$home = "/home/${username}"


package{['gvfs-bin','libgnome-keyring-dev']:
  ensure => present,
  before => Package['slack-desktop'],
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
  },
}

create_resources(download_package_install,$package_details)

###################################################################
# Configuration of Sublime Text
###################################################################
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
  ]:
  ensure => present,
}

###################################################################
# Fonts
###################################################################
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
ohmyzsh::install { ['root', 'josh']: }
ohmyzsh::theme { ['root', 'josh']: 
  theme => 'agnoster' 
} # specific theme
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

file{"${home}/workspace/keepass":
  ensure => directory,
}

$clipass_root = "${home}/workspace/keepass/clipass"
$clipass_path = "${clipass_root}/clipass.php"

file { "${home}/AK Scripts/pw-pk.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'ProKarma'}),
}
file { "${home}/AK Scripts/pw-tmo1.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'T-Mobile NTid'}),
}
file { "${home}/AK Scripts/pw-tmo2.py":
  ensure  => file,
  content => inline_epp($autokey_keepass_template, {'keepass_key' => 'T-Mobile two'}),
}
file { "${home}/AK Scripts/Email.txt":
  ensure  => file,
  content => '@prokarma.com',
}
file { "${home}/AK Scripts/Username.txt":
  ensure  => file,
  content => 'jsouza',
}

# CliPass
$composer_template = @(END)
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('SHA384', 'composer-setup.php') === '070854512ef404f16bac87071a6db9fd9721da1684cd4589b1196c3faf71b9a2682e2311b36a5079825e155ac7ce150d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
END

vcsrepo{$clipass_root:
  ensure => present,
  provider => 'git',
  source => 'https://github.com/bartlomiej-dudala/clipass.git',
} -> 
file{"${clipass_root}/get_composer.sh":
  content => inline_epp($composer_template),
  mode => '0755',
} ->
exec{"install_composer":
  cwd => $clipass_root,
  command => "${clipass_root}/get_composer.sh",
  # This is wrong, I just don't know what is correct
  creates => "${clipass_root}/vendor",
} -> 
exec{"install clipass":
  cwd => $clipass_root,
  command => "/usr/bin/php composar.phar install",
  # This is wrong, I just don't know what is correct
  creates => "${clipass_root}/vendor/autoload.php",
}
notice("You may need to run the composer stuff in ${clipass_root} manually?")
