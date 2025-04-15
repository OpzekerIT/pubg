
<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Check out the top 20 PUBG player rankings in key performance categories! Explore leaderboards for metrics like damage dealt, headshot kills, and more across different game modes. Stay on top of the competitive scene and see where you or your favorite players stand in our regularly updated stats.";

// Include config if it exists
$configPath = './config/config.php';
if (file_exists($configPath)) {
    include $configPath;
}

$players_data = null;
$topPlayersByAttribute = [];
$dataError = '';
$lastUpdated = 'N/A';
// Define available modes (expanded for consistency, though only some are used in the form below)
$availableModes = ['solo', 'duo', 'squad', 'solo-fpp', 'duo-fpp', 'squad-fpp'];
// Attributes to display leaderboards for
$attributes = ['wins', 'top10s', 'kills', 'dBNOs', 'damageDealt', 'headshotKills', 'roadKills', 'teamKills', 'roundMostKills'];

// Determine selected game mode (using GET)
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
            // Prepare sorted data for each attribute
            foreach ($attributes as $attribute) {
                $currentModeData = $players_data[$selected_mode]; // Work with a copy for sorting

                // Sort players based on the current attribute (descending)
                uasort($currentModeData, function ($a, $b) use ($attribute) {
                    $account_id_a = array_key_first($a);
                    $account_id_b = array_key_first($b);
                    // Use null coalescing operator for safety
                    $stat_a = $a[$account_id_a][$attribute] ?? 0;
                    $stat_b = $b[$account_id_b][$attribute] ?? 0;
                    return $stat_b <=> $stat_a; // Sort descending
                });

                // Get top 20 players for this attribute
                $topPlayersByAttribute[$attribute] = array_slice($currentModeData, 0, 20, true);
            }
             if (empty($topPlayersByAttribute)) {
                 $dataError = "No player stats found to generate leaderboards for mode: " . htmlspecialchars($selected_mode);
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
        <h2>Top 20 Player Rankings</h2>

        <?php if ($dataError): ?>
            <p style="color: red;"><?php echo htmlspecialchars($dataError); ?></p>
        <?php endif; ?>

        <!-- Form to select game mode (using GET) -->
        <form method="get" action="">
            <?php // Only show buttons for modes relevant to this page if desired, or keep all available modes ?>
            <input type="submit" name="game_mode" value="solo" class="btn<?php echo ('solo' === $selected_mode) ? ' active' : ''; ?>">
            <input type="submit" name="game_mode" value="duo" class="btn<?php echo ('duo' === $selected_mode) ? ' active' : ''; ?>">
            <input type="submit" name="game_mode" value="squad" class="btn<?php echo ('squad' === $selected_mode) ? ' active' : ''; ?>">
             <input type="submit" name="game_mode" value="solo-fpp" class="btn<?php echo ('solo-fpp' === $selected_mode) ? ' active' : ''; ?>">
            <input type="submit" name="game_mode" value="duo-fpp" class="btn<?php echo ('duo-fpp' === $selected_mode) ? ' active' : ''; ?>">
            <input type="submit" name="game_mode" value="squad-fpp" class="btn<?php echo ('squad-fpp' === $selected_mode) ? ' active' : ''; ?>">
        </form>
        <br>

        <?php if (!empty($topPlayersByAttribute)): ?>
            <?php foreach ($topPlayersByAttribute as $attribute => $topPlayers): ?>
                <h3>Top 20 <?php echo htmlspecialchars($attribute); ?> (<?php echo htmlspecialchars(ucfirst($selected_mode)); ?>)</h3>
                <?php if (empty($topPlayers)): ?>
                    <p>No data available for this attribute in the selected mode.</p>
                <?php else: ?>
                    <table border="1">
                        <thead>
                            <tr>
                                <th>Player</th>
                                <th><?php echo htmlspecialchars($attribute); ?></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($topPlayers as $player_name => $player_details):
                                $account_id = array_key_first($player_details);
                                $statValue = $player_details[$account_id][$attribute] ?? 'N/A';
                            ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($player_name); ?></td>
                                    <td><?php echo htmlspecialchars($statValue); ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                    <br>
                <?php endif; ?>
            <?php endforeach; ?>
        <?php elseif (!$dataError): ?>
            <p>No leaderboards to display for the selected mode.</p>
        <?php endif; ?>

        <p>Last update: <?php echo $lastUpdated; ?></p>

    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
