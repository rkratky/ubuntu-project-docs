#!/bin/bash

TEAMS_CONF=lp-teams.csv

if [ -f "$TEAMS_CONF" ]; then
    declare -A TEAMS
    while IFS=',' read -r team teamfile; do
        TEAMS["$team"]="$teamfile"
    done <"$TEAMS_CONF"
else
    exit
fi

for LP_TEAM in "${!TEAMS[@]}"; do
    TEAM_FILE="${TEAMS[$LP_TEAM]}"
    CURL_CALL="curl --silent https://api.launchpad.net/1.0/~${LP_TEAM}/members"
    CURL_OUTPUT=$($CURL_CALL | jq -r '.entries[] | .name' | sort)

    if [ -f "$TEAM_FILE" ]; then
        EXISTING_TEAM=$(cat "$TEAM_FILE")
    else
        EXISTING_TEAM=""
    fi

    if [ "$CURL_OUTPUT" != "$EXISTING_TEAM" ]; then
        git config --local user.email "github-actions[bot]@users.noreply.github.com"
        git config --local user.name "github-actions[bot]"

        BRANCH_NAME="update-$LP_TEAM-$(date +'%Y%m%d-%H%M%S')"

        git checkout -b "$BRANCH_NAME"

        echo "$COMMAND_OUTPUT" >"$TEAM_FILE"

        git add .
        git commit -m "Update '$LP_TEAM' team in $TEAM_FILE"
        git push origin "$BRANCH_NAME"

        gh pr create -B main -H "$BRANCH_NAME" \
            --title "Update $LP_TEAM team" \
            --body "Automatically generated PR to update $LP_TEAM team in $TEAM_FILE"
    else
        echo "No changes detected for $TEAM_FILE."
    fi
done
