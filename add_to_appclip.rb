#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

# ————— CONFIG —————
PROJECT_PATH = 'Stitch.xcodeproj'
SOURCE_GLOB  = 'Stitch/**/*.swift'   # all your Swift files
TARGET_NAME  = 'StitchAppClip'
# ————————————

# Open the project
proj = Xcodeproj::Project.open(PROJECT_PATH)
target = proj.targets.find { |t| t.name == TARGET_NAME }
unless target
  abort "❌ Target #{TARGET_NAME} not found!"
end

added = 0
Dir.glob(SOURCE_GLOB).each do |path|
  # Debug: list all project file paths when no direct match yet
  unless defined?(all_paths_logged)
    puts "📁 Project reference paths:"
    proj.files.each { |f| puts " - #{f.path}" }
    all_paths_logged = true
  end

  # Find the file reference in the project by exact match, suffix match, or filename
  file_ref = proj.files.find do |f|
    f.path == path ||
    (f.path && f.path.end_with?(path)) ||
    File.basename(f.path) == File.basename(path)
  end

  if file_ref
    # Add it to the target if it's not already there
    unless target.source_build_phase.files_references.include?(file_ref)
      target.add_file_references([file_ref])
      puts "✅ #{path}"
      added += 1
    end
  else
    puts "⚠️  #{path} not in project; skipping"
  end
end

proj.save
puts "\n✅ Finished: #{added} file(s) added to #{TARGET_NAME}"