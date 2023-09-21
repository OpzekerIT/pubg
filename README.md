# DTCH - PUBG Clan User Stats

This project displays the user statistics for members of the DTCH PUBG Clan.
While the code is tailored for the DTCH clan, you can modify it to suit your specific clan or needs.

## Features

1. Display lifetime stats for a specific game mode (solo, duo, squad).
2. Select a player from the DTCH clan and view their stats.

## Prerequisites

- PHP 7.4 or higher
- cURL extension for PHP

## Installation

1. Clone this repository:
   \`\`\`
   git clone [repository-url]
   \`\`\`

2. Navigate to the project directory:
   \`\`\`
   cd [project-directory]
   \`\`\`

3. Rename the `config/config.php.rename` to `config/config.php`.

4. Update the `config/config.php` file with the appropriate API key and clan members.

5. Host the project on a PHP server (like Apache).

6. Access the `user_stats.php` in your browser to view the stats.

## Usage

1. Select a game mode to view stats (solo, duo, squad).
2. Choose a clan member to view their specific stats.
3. The rate limit headers for the PUBG API are displayed at the top.
4. Modify the PHP files to adjust them to your requirements.

## Notes

- Ensure that the API key is kept confidential and not exposed to the public.
- The project comes with a rate limiter (`ratelimiter.php`), which can be included to restrict the frequency of page access.
- While this project is designed specifically for the DTCH clan, you will need to adjust various parts of the code to make it suitable for your clan or specific requirements.

## License

This project is open-source. Feel free to modify and distribute as per your needs.
\`\`\`
