<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Explore detailed player statistics over the past month including win percentages, K/D ratios in human and all-player categories, total kills, and more. Delve into stats for various match types like Intense, Casual, Official, Custom, and Ranked, and see how players have fared in a minimum number of matches. Stay informed with the latest updates on player performance.";

// Include config if it exists
$configPath = './config/config.php';
if (file_exists($configPath)) {
    include $configPath;
}

$clanmembersData = null;
$alts = [];
$playersStatsData = null;
$processedStats = [];
$dataError = '';
$lastUpdated = 'N/A';

// Category definitions with minimum match requirements and display names
$categories = [
    // 'all' => ['min_matches' => 25, 'display_name' => 'All Matches (min 25)'], // Skipping 'all' as per original logic
    'clan_casual' => ['min_matches' => 18, 'display_name' => 'Clan Casual (min 18 matches, min 2 clan players)'],
    'Intense' => ['min_matches' => 18, 'display_name' => 'Intense BR (min 18 matches)'],
    'Casual' => ['min_matches' => 18, 'display_name' => 'Casual (min 18 matches)'],
    'official' => ['min_matches' => 18, 'display_name' => 'Official (min 18 matches)'],
    'custom' => ['min_matches' => 8, 'display_name' => 'Custom (min 8 matches)'],
    'Ranked' => ['min_matches' => 8, 'display_name' => 'Ranked (min 8 matches)'],
];

// Load clan members to identify alts
$clanMembersPath = './config/clanmembers.json';
if (file_exists($clanMembersPath)) {
    $clanmembersJson = file_get_contents($clanMembersPath);
    $clanmembersData = json_decode($clanmembersJson, true);
    if (isset($clanmembersData['alts']) && is_array($clanmembersData['alts'])) {
        $alts = $clanmembersData['alts'];
    } else {
        $dataError .= " Error reading or invalid format for 'alts' in clan members file.";
    }
} else {
    $dataError .= " Clan members file not found.";
}

// Load player stats data
$statsPath = './data/player_last_stats.json';
if (file_exists($statsPath)) {
    $statsJson = file_get_contents($statsPath);
    $playersStatsData = json_decode($statsJson, true);

    if (!is_array($playersStatsData)) {
        $dataError .= " Error decoding player last stats data.";
        $playersStatsData = null;
    } else {
        $lastUpdated = htmlspecialchars($playersStatsData['updated'] ?? 'N/A');

        // Process stats for each defined category
        foreach ($categories as $key => $categoryInfo) {
            if (isset($playersStatsData[$key]) && is_array($playersStatsData[$key])) {
                $categoryStats = [];
                foreach ($playersStatsData[$key] as $player_data) {
                    // Basic validation and alt check
                    if (!isset($player_data['playername']) || is_null($player_data['playername']) || in_array($player_data['playername'], $alts)) {
                        continue;
                    }

                    // Minimum matches check
                    $matchesPlayed = $player_data['matches'] ?? 0;
                    if ($matchesPlayed < $categoryInfo['min_matches']) {
                        continue;
                    }

                    // Format stats for display
                    $formatted_player_data = [];
                    $formatted_player_data['playername'] = htmlspecialchars($player_data['playername']);
                    $formatted_player_data['deaths'] = number_format($player_data['deaths'] ?? 0, 0, ',', '');
                    $formatted_player_data['kills'] = number_format($player_data['kills'] ?? 0, 0, ',', '');
                    $formatted_player_data['humankills'] = number_format($player_data['humankills'] ?? 0, 0, ',', '');
                    $formatted_player_data['matches'] = htmlspecialchars($matchesPlayed);
                    $formatted_player_data['wins'] = number_format($player_data['wins'] ?? 0, 0, ',', '');
                    $formatted_player_data['winratio'] = number_format($player_data['winratio'] ?? 0, 2, ',', '');
                    $formatted_player_data['ahd'] = number_format($player_data['ahd'] ?? 0, 2, ',', '');

                    // Format K/D (handle null, Infinity, non-numeric)
                    $kd_h_raw = $player_data['KD_H'] ?? null;
                    $formatted_player_data['KD_H'] = ($kd_h_raw === null) ? "N/A" : (($kd_h_raw == "Infinity") ? "∞" : (is_numeric($kd_h_raw) ? number_format((float)$kd_h_raw, 2, ',', '') : "0"));
                    $kd_all_raw = $player_data['KD_ALL'] ?? null;
                    $formatted_player_data['KD_ALL'] = ($kd_all_raw === null) ? "N/A" : (($kd_all_raw == "Infinity") ? "∞" : (is_numeric($kd_all_raw) ? number_format((float)$kd_all_raw, 2, ',', '') : "0"));

                    // Format change indicator
                    $originalChange = isset($player_data['change']) ? str_replace(',', '.', $player_data['change']) : '0';
                    $changeValue = floatval($originalChange);
                    $formatted_player_data['change_value'] = number_format($changeValue, 2, ',', ''); // Display formatted number
                    if ($changeValue < 0) {
                        $formatted_player_data['change_image'] = 'images/red.png';
                        $formatted_player_data['change_alt'] = 'Decrease';
                    } elseif ($changeValue > 0) {
                        $formatted_player_data['change_image'] = 'images/green.png';
                        $formatted_player_data['change_alt'] = 'Increase';
                    } else {
                        $formatted_player_data['change_image'] = 'images/equal.png';
                        $formatted_player_data['change_alt'] = 'No change';
                    }

                    $categoryStats[] = $formatted_player_data;
                }
                $processedStats[$key] = $categoryStats;
            }
        }
    }
} else {
    $dataError .= " Player last stats data file not found.";
}

?>
<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; // Includes $ogDescription ?>
<body>

    <?php
    include './includes/navigation.php';
    include './includes/header.php';
    ?>

    <main>
        <section>
            <h2>Player Stats Past Quarter</h2>

            <?php if (trim($dataError)): ?>
                <p style="color: red;"><?php echo htmlspecialchars(trim($dataError)); ?></p>
            <?php endif; ?>

            <?php foreach ($categories as $key => $categoryInfo): ?>
                <?php if (isset($processedStats[$key])): ?>
                    <br>
                    <h3><?php echo htmlspecialchars($categoryInfo['display_name']); ?></h3>
                    <?php if (empty($processedStats[$key])): ?>
                        <p>No players met the criteria for this category.</p>
                    <?php else: ?>
                        <table border="1" class="sortable">
                            <thead>
                                <tr>
                                    <th>Player</th>
                                    <th>Win %</th>
                                    <th>AHD</th>
                                    <th>K/D Human</th>
                                    <th>Human Kills</th>
                                    <th>K/D All</th>
                                    <th>Kills</th>
                                    <th>Matches</th>
                                    <th>Wins</th>
                                    <th>Deaths</th>
                                    <th>Win % Change</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($processedStats[$key] as $player_stat):
                                    $playerLink = 'latestmatches.php?selected_player=' . urlencode($player_stat['playername']);
                                ?>
                                <tr>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['playername']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['winratio']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['ahd']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['KD_H']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['humankills']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['KD_ALL']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['kills']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['matches']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['wins']; ?></a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $player_stat['deaths']; ?></a></td>
                                    <td style="line-height: 17px;">
                                        <img src="<?php echo htmlspecialchars($player_stat['change_image']); ?>" alt="<?php echo htmlspecialchars($player_stat['change_alt']); ?>" style="vertical-align: middle;" width="17" height="17"/>
                                        <?php echo $player_stat['change_value']; ?>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                <?php endif; ?>
            <?php endforeach; ?>

            <p>Last update: <?php echo $lastUpdated; ?></p>

        </section>
    </main>

    <?php include './includes/footer.php'; ?>

</body>
</html>
