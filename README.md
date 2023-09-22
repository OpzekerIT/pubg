# DTCH - PUBG Clan User Stats

This project displays the user statistics for members of the DTCH PUBG Clan. While the code is tailored for the DTCH clan, you can modify it to suit your specific clan or needs.

## Features

1. Display lifetime stats for a specific game mode (solo, duo, squad).
2. Select a player from the DTCH clan and view their stats.

## Prerequisites

- PHP 7.4 or higher
- cURL extension for PHP
- PowerShell installed on your system
#
## Installation

1. Clone this repository:

git clone [repository-url]

2. Navigate to the project directory:

cd [project-directory]

3. Rename the `config/config.php.rename` to `config/config.php`.

4. Update the `config/config.php` file with the appropriate API key and clan members.

5. Host the project on a PHP server (like Apache).

## Usage

1. Use the PowerShell scripts in the `update` folder to generate the JSON files that are used in the clan and user PHP files.
 - `update_clan_member.ps1`: Update this once every 30 minutes. It's recommended to set up a cron job or scheduled task for this.
 - `update_clan.ps1`: Update this once every day.

## Notes

- Ensure that the API key is kept confidential and not exposed to the public.
- The project comes with a rate limiter (`ratelimiter.php`), which can be included to restrict the frequency of page access.
- While this project is designed specifically for the DTCH clan, you will need to adjust various parts of the code to make it suitable for your clan or specific requirements.

## License

This project is open-source. Feel free to modify and distribute as per your needs.
