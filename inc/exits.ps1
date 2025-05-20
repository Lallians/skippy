# Array that contains every error codes and associated error messages.
# $exits[1] is also used in parts of Skippy that have not access to this array.
$exits = @{
    1 = '❌ An error has occured.'
    2 = '❌ Could not create directories "db" or "www" during creation.'
    3 = '❌ Template not found:'
    4 = '❌ Template does not exists for platform: '
    5 = '❗ Project already exists! Aborting...'
}