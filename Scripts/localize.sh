LOCALIZE_PATH="$2"
LOCALIZE_API="$3"
LOCALIZE_TOKEN="$4"

# Config for Strings struct (Optional to change)
STRINGS_STRUCT_NAME="$5"

# Sync the translations from remote
SyncTranslations() {
    # Initialise temp variables
    PACKAGE_NAME="RuntimeLocalization"
    STRINGS_FILE_NAME="${STRINGS_STRUCT_NAME}.swift"
    JSON_FILE="$LOCALIZE_PATH/Contents.json"

    # Pre Cleanup
    rm -rf "$JSON_FILE"

    # Fetching the data and storing it into the temp json file
    touch "$JSON_FILE"
    curl $LOCALIZE_API --header "Authorization: $LOCALIZE_TOKEN" >> "$LOCALIZE_PATH/Contents.json"

    # Continue only if json is valid
    if jq -e . >/dev/null 2>&1 "$JSON_FILE"; then

        DeleteInPath() {
            find "$LOCALIZE_PATH" -maxdepth 1 -name $1 | while read filepath ; do
                rm -rf "$filepath"
            done
        }

        DeleteInPath "*.lproj"
        DeleteInPath "$STRINGS_FILE_NAME"

        # Make file in path
        MakeFileInPath() {
            touch "$LOCALIZE_PATH/$1"
        }

        # Make file and folders needed for the translation
        MakeFileForLang() {
            mkdir -p "$LOCALIZE_PATH/$1.lproj"
            MakeFileInPath "$1.lproj/Localizable.strings"
        }

        # writing the translations to the required files
        jq -r 'keys[]' "$JSON_FILE" | while IFS= read -r key ; do
            jq -r --arg k "$key" '.[$k] | keys[]' "$JSON_FILE" | while IFS= read -r lang ; do
                value=$(jq --arg k "$key" --arg l "$lang" '.[$k][$l]' "$JSON_FILE")
                MakeFileForLang "$lang"
                echo "\"$key\" = $value;" >> "$LOCALIZE_PATH/$lang.lproj/Localizable.strings"
            done
        done

        # Make the strings file to append data to it
        MakeFileInPath "$STRINGS_FILE_NAME"
        # Add line to Strings file
        AddLineToStrings() {
            echo "$1" >> "$LOCALIZE_PATH/$STRINGS_FILE_NAME"
        }
        # Open the swift file with requirements and file name
        current_date=$(date +%s)
        AddLineToStrings "import $PACKAGE_NAME"
        AddLineToStrings ""
        AddLineToStrings "public struct $STRINGS_STRUCT_NAME: LocalizeProtocol {"
        AddLineToStrings ""
        AddLineToStrings "    public static let versionNumber: Int = $current_date"
        AddLineToStrings ""
        # Add all the keys as static parameters to the swift file
        jq -r 'keys[]' "$JSON_FILE" | while IFS= read -r key ; do
            new_name=$(echo "$key" | perl -nE 'say lcfirst join "", map {ucfirst lc} split /[^[:alnum:]]+/')
            AddLineToStrings "    public static let $new_name = \"$key\""
        done
        # Close the swift file
        AddLineToStrings "}"

        echo "Updated all languages at: $LOCALIZE_PATH"

    else
        echo "Failed to fetch or Invalid data"
    fi


    # CleanUP
    rm "$JSON_FILE"
}

InstalTooling() {
    curl -sS https://webi.sh/jq | sh
}


if [ "$1" == "installTooling" ]
then
    InstalTooling
elif [ "$1" == "sync" ]
then
    SyncTranslations
else
    echo "Command not found, Valid commands: installTooling , sync"
fi
