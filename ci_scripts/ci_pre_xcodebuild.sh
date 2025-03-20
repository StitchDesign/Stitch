#!/bin/sh

#  ci_pre_xcodebuild.sh
#  Stitch
#
#  Created by Nicholas Arner on 1/24/25.
#  


echo "Stage: PRE-Xcode Build is activated .... "

# Navigate to the root directory where the secrets.json file is stored
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

# Write the environment variables to the secrets.json file
printf '{
    "SUPABASE_URL": "%s",
    "SUPABASE_ANON_KEY": "%s",
    "SUPABASE_TABLE_NAME": "%s",
    "OPEN_AI_API_KEY": "%s",
    "OPEN_AI_MODEL": "%s",
    "SENTRY_DSN": "%s"
}' "$SUPABASE_URL" "$SUPABASE_ANON_KEY" "$SUPABASE_TABLE_NAME" "$OPEN_AI_API_KEY" "$OPEN_AI_MODEL" "$SENTRY_DSN" > secrets.json

echo "Wrote secrets.json file to the root of the repository."

echo "Stage: PRE-Xcode Build is DONE .... "

exit 0
