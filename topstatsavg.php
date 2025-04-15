<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Discover comprehensive average statistics for PUBG players. Dive into player performance across various game modes including solo, duo, and squad, and explore key metrics like Kills, Damage, Headshots, Wins, and Top10s. Stay updated with the latest statistical trends in PUBG gaming.";

// Include config if it exists
$configPath = './config/config.php';
if (file_exists($configPath)) {
    include $configPath;
}

$players_data = null;
$playerAverages = [];
$dataError = '';
$lastUpdated = 'N/A';
$availableModes = ['solo', 'duo', 'squad', 'solo-fpp', 'duo-fpp', 'squad-fpp']; // Define available modes (expanded for consistency)
$metrics = [
    'Kills' => 'kills',
    'Damage' => 'damageDealt',
    'Headshots' => 'headshotKills',
    'Wins' => 'wins',
    'Top10s' => 'top10s'
];

// Determine selected game mode (using GET for consistency)
$selected_mode = isset($_GET['game_mode']) && in_array($_GET['game_mode'], $availableModes) ? $_GET['game_mode'] : 'squad';

// Load player lifetime data
$dataPath = './data/player_lifetime_data.json';
if (file_exists($dataPath)) {
    $jsonData = file_get_contents($dataPath);
    $players_data = json_decode($jsonData, true);

    if (!is_array($players_data)) {
        $dataError = "Error decoding player lifetime data.";
        $players_data = null; // Ensure it's null if decoding failed
    } else {
        $lastUpdated = htmlspecialchars($players_data['updated'] ?? 'N/A');

        // Check if the selected mode exists in the data
        if (isset($players_data[$selected_mode]) && is_array($players_data[$selected_mode])) {
            // Calculate averages for each player in the selected mode
            foreach ($players_data[$selected_mode] as $player_name => $player_details) {
                $account_id = array_key_first($player_details);
                if ($account_id && isset($player_details[$account_id])) {
                    $stats = $player_details[$account_id];
                    // Ensure necessary stats exist before calculation
                    $wins = $stats['wins'] ?? 0;
                    $losses = $stats['losses'] ?? 0;
                    $totalGames = $wins + $losses;

                    $averages = [];
                    foreach ($metrics as $metricKey) {
                        $statValue = $stats[$metricKey] ?? 0;
                        $averages[$metricKey] = ($totalGames > 0) ? round($statValue / $totalGames, 2) : 0;
                    }
                    $playerAverages[$player_name] = $averages;
                }
            }
            if (empty($playerAverages)) {
                 $dataError = "No player stats found to calculate averages for mode: " . htmlspecialchars($selected_mode);
            }
        } else {
            $dataError = "Selected game mode (" . htmlspecialchars($selected_mode) . ") not found in data.";
        }
    }
} else {
    $dataError = "Player lifetime data file not found.";
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
        <h2>Average User Stats</h2>

        <?php if ($dataError): ?>
            <p style="color: red;"><?php echo htmlspecialchars($dataError); ?></p>
        <?php endif; ?>

        <!-- Form to select game mode (using GET) -->
        <form method="get" action="">
            <?php foreach ($availableModes as $mode): ?>
                <input type="submit" name="game_mode" value="<?php echo htmlspecialchars($mode); ?>" class="btn<?php echo ($mode === $selected_mode) ? ' active' : ''; ?>">
            <?php endforeach; ?>
        </form>
        <br>

        <?php if (!empty($playerAverages)): ?>
            <table border="1" class="sortable">
                <thead>
                    <tr>
                        <th>Player</th>
                        <?php foreach ($metrics as $display => $metric): ?>
                            <th>Average <?php echo htmlspecialchars($display); ?></th>
                        <?php endforeach; ?>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($playerAverages as $player_name => $averages): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($player_name); ?></td>
                            <?php foreach ($metrics as $metricKey): ?>
                                <td><?php echo htmlspecialchars($averages[$metricKey] ?? '0'); ?></td>
                            <?php endforeach; ?>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <br>
        <?php elseif (!$dataError): ?>
            <p>No average stats to display for the selected mode.</p>
        <?php endif; ?>

        <p>Last update: <?php echo $lastUpdated; ?></p>

    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
