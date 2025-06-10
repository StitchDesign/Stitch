from mod_pbxproj import XcodeProject
from mod_pbxproj.pbxextensions.ProjectFiles import FileOptions
import os

project_path = "Stitch.xcodeproj/project.pbxproj"
source_folder = "Stitch"
destination_target_name = "StitchAppClip"

project = XcodeProject.load(project_path)
destination_target = project.get_target_by_name(destination_target_name)

if not destination_target:
    raise Exception(f"Target '{destination_target_name}' not found")


# Collect all Swift file paths under the source folder
options = FileOptions(create_build_files=True)
swift_paths = []
for root, _, files in os.walk(source_folder):
    for fname in files:
        if fname.endswith('.swift'):
            rel = os.path.relpath(os.path.join(root, fname), os.getcwd())
            swift_paths.append(rel)
            print(f"🔍 Found Swift file: {rel}")

# Add all Swift files to the target, skipping existing ones
added_paths = project.add_files(swift_paths, file_options=options, target_name=destination_target_name, force=False)
for added in added_paths:
    print(f"✅ Added {added.path} to {destination_target_name}")

# Optionally remove the backup, as add_files already handles file references
# project.backup()
project.save()
print(f"\n✅ Finished: {len(added_paths)} .swift file(s) added to target '{destination_target_name}'")
