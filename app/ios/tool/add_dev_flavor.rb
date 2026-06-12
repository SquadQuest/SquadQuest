#!/usr/bin/env ruby
# Adds the `dev` iOS flavor to Runner.xcodeproj, mirroring the Android dev flavor
# (app.squadquest.dev / "SquadQuest Dev"). Run from app/ios:  ruby tool/add_dev_flavor.rb
#
# Flutter resolves `flutter build ipa --flavor dev` to an Xcode scheme named "dev"
# whose configs are "<Base>-dev" (e.g. Release-dev). So for each existing config we
# add a "<name>-dev" copy at the project level and on every target, point the Runner
# dev-configs at app.squadquest.dev + "SquadQuest Dev", and add a shared `dev` scheme.
#
# Idempotent: re-running detects the existing dev configs/scheme and makes no change.
require 'xcodeproj'

PROJECT = 'Runner.xcodeproj'
DEV_BUNDLE = 'app.squadquest.dev'
DEV_NAME = 'SquadQuest Dev'
SUFFIX = '-dev'

project = Xcodeproj::Project.open(PROJECT)
changed = false

# Base config names present today (Debug/Release/Profile), excluding any *-dev.
base_names = project.build_configuration_list.build_configurations
                    .map(&:name).reject { |n| n.end_with?(SUFFIX) }.uniq

# Duplicate a config within a given XCConfigurationList if the -dev variant is absent.
dup_into = lambda do |list, owner_label|
  base_names.each do |base|
    dev = "#{base}#{SUFFIX}"
    next if list.build_configurations.any? { |c| c.name == dev }
    src = list.build_configurations.find { |c| c.name == base }
    next unless src
    c = list.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    c.name = dev
    c.build_settings = Marshal.load(Marshal.dump(src.build_settings)) # deep copy
    c.base_configuration_reference = src.base_configuration_reference
    list.build_configurations << c
    changed = true
    puts "  + #{owner_label}: #{dev}"
  end
end

# 1) project-level configs
dup_into.call(project.build_configuration_list, 'project')

# 2) per-target configs (+ Runner dev identity overrides)
project.targets.each do |t|
  dup_into.call(t.build_configuration_list, "target #{t.name}")
  next unless t.name == 'Runner'
  t.build_configuration_list.build_configurations.each do |c|
    next unless c.name.end_with?(SUFFIX)
    if c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] != DEV_BUNDLE
      c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = DEV_BUNDLE
      changed = true
    end
    # Display name via build setting (Info.plist CFBundleDisplayName reads it).
    if c.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] != DEV_NAME
      c.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = DEV_NAME
      changed = true
    end
  end
end

project.save if changed

# 3) shared `dev` scheme (Flutter looks one up by flavor name). Build it from the
# existing Runner scheme so launch/test/profile/archive actions match, then retarget
# its configs to the -dev variants.
schemes_dir = File.join(PROJECT, 'xcshareddata', 'xcschemes')
dev_scheme_path = File.join(schemes_dir, 'dev.xcscheme')
if File.exist?(dev_scheme_path)
  puts '  = dev.xcscheme already present'
else
  scheme = Xcodeproj::XCScheme.new(File.join(schemes_dir, 'Runner.xcscheme'))
  xml = scheme.to_s
  # Map each base config name to its -dev variant in the scheme's buildConfiguration attrs.
  base_names.each { |b| xml = xml.gsub("buildConfiguration = \"#{b}\"", "buildConfiguration = \"#{b}#{SUFFIX}\"") }
  File.write(dev_scheme_path, xml)
  puts '  + dev.xcscheme'
  changed = true
end

puts changed ? 'dev flavor applied.' : 'dev flavor already present — no change.'
