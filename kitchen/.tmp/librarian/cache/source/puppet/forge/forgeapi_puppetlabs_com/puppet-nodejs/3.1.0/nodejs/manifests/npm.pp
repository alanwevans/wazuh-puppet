# See README.md for usage information.
define nodejs::npm (
  Stdlib::Absolutepath $target,
  Pattern[/^[^<            >= ]/] $ensure            = 'present',
  $cmd_exe_path             = $nodejs::cmd_exe_path,
  Array $install_options    = [],
  $npm_path                 = $nodejs::npm_path,
  String $package           = $title,
  $source                   = 'registry',
  Array $uninstall_options  = [],
  $home_dir                 = '/root',
  $user                     = undef,
) {

  $install_options_string = join($install_options, ' ')
  $uninstall_options_string = join($uninstall_options, ' ')

  # Note that install_check will always return false when a remote source is
  # provided
  if $source != 'registry' {
    $install_check_package_string = $source
    $package_string = $source
  } elsif $ensure =~ /^(present|absent)$/ {
    $install_check_package_string = $package
    $package_string = $package
  } else {
  # ensure is either a tag, version or 'latest'
  # Note that install_check will always return false when 'latest' or a tag is
  # provided
  # npm ls does not keep track of tags after install
    $install_check_package_string = "${package}:${package}@${ensure}"
    $package_string = "${package}@${ensure}"
  }

  $grep_command = $::osfamily ? {
    'Windows' => "${cmd_exe_path} /c findstr /l",
    default   => 'grep',
  }

  $install_check = $::osfamily ? {
    'Windows' => "${npm_path} ls --long --parseable | ${grep_command} \"${target}\\node_modules\\${install_check_package_string}\"",
    default   => "${npm_path} ls --long --parseable | ${grep_command} \"${target}/node_modules/${install_check_package_string}\"",
  }

  if $ensure == 'absent' {
    $npm_command = 'rm'
    $options = $uninstall_options_string

    exec { "npm_${npm_command}_${name}":
      command => "${npm_path} ${npm_command} ${package_string} ${options}",
      onlyif  => $install_check,
      user    => $user,
      cwd     => $target,
      require => Class['nodejs'],
    }
  } else {
    $npm_command = 'install'
    $options = $install_options_string
    # Conditionally require proxy and https-proxy to be set first only if the resource exists.
    Nodejs::Npm::Global_config_entry<| title == 'https-proxy' |> -> Exec["npm_install_${name}"]
    Nodejs::Npm::Global_config_entry<| title == 'proxy' |> -> Exec["npm_install_${name}"]

    exec { "npm_${npm_command}_${name}":
      command     => "${npm_path} ${npm_command} ${package_string} ${options}",
      unless      => $install_check,
      user        => $user,
      cwd         => $target,
      environment => "HOME=${home_dir}",
      require     => Class['nodejs'],
    }
  }
}
