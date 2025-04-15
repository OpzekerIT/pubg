<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Explore detailed lifetime statistics of PUBG players in various game modes including solo, duo, and squad. Choose your favorite mode and player to view their performance stats, victories, and more, updated regularly.";

// Include config if it exists
$configPath = './config/config.php';
if (file_exists($configPath)) {
    include $configPath;
} else {
    // Handle missing config file, maybe set defaults or show an error
    // For now, we'll proceed assuming defaults or that it's not strictly required for this page structure
}

$players_data = null;
$stats = null;
$selected_player = null;
$dataError = '';
$lastUpdated = 'N/A';
$availableModes = ['solo', 'duo', 'squad', 'solo-fpp', 'duo-fpp', 'squad-fpp']; // Define available modes

// Determine selected game mode
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
            // Determine selected player
            $availablePlayers = array_keys($players_data[$selected_mode]);
            $selected_player_from_get = $_GET['selected_player'] ?? null;

            if ($selected_player_from_get && in_array($selected_player_from_get, $availablePlayers)) {
                $selected_player = $selected_player_from_get;
            } elseif (!empty($availablePlayers)) {
                $selected_player = $availablePlayers[0]; // Default to the first player if none selected or invalid
            }

            // Fetch the player stats if a player is selected
            if ($selected_player && isset($players_data[$selected_mode][$selected_player])) {
                $account_id = array_key_first($players_data[$selected_mode][$selected_player]);
                if ($account_id && isset($players_data[$selected_mode][$selected_player][$account_id])) {
                    $stats = $players_data[$selected_mode][$selected_player][$account_id];
                } else {
                    $dataError = "Could not find account ID or stats for the selected player.";
                }
            } elseif (empty($availablePlayers)) {
                 $dataError = "No players found for the selected game mode: " . htmlspecialchars($selected_mode);
            } else {
                 $dataError = "Selected player not found or no player selected for this mode.";
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
        <h2>User Stats</h2>

        <?php if ($dataError): ?>
            <p style="color: red;"><?php echo htmlspecialchars($dataError); ?></p>
        <?php endif; ?>

        <!-- Form to select game mode -->
        <form method="get" action="">
            <?php foreach ($availableModes as $mode): ?>
                <input type="submit" name="game_mode" value="<?php echo htmlspecialchars($mode); ?>" class="btn<?php echo ($mode === $selected_mode) ? ' active' : ''; ?>">
            <?php endforeach; ?>
            <?php if ($selected_player): // Keep selected player if switching modes ?>
                 <input type="hidden" name="selected_player" value="<?php echo htmlspecialchars($selected_player); ?>">
            <?php endif; ?>
        </form>
        <br>

        <?php if (isset($players_data[$selected_mode]) && is_array($players_data[$selected_mode]) && !empty($players_data[$selected_mode])): ?>
            <!-- Buttons for each player -->
            <form method="get" action="">
                <?php foreach ($players_data[$selected_mode] as $player_name => $player_details): ?>
                    <button type="submit" name="selected_player" value="<?php echo htmlspecialchars($player_name); ?>" class="btn<?php echo ($player_name === $selected_player) ? ' active' : ''; ?>">
                        <?php echo htmlspecialchars($player_name); ?>
                    </button>
                <?php endforeach; ?>
                <input type="hidden" name="game_mode" value="<?php echo htmlspecialchars($selected_mode); ?>">
            </form>
            <br>
        <?php endif; ?>

        <?php if ($selected_player && $stats): ?>
            <h2><?php echo htmlspecialchars(ucfirst($selected_mode)); ?> Lifetime Stats for <?php echo htmlspecialchars($selected_player); ?></h2>
            <table border="1">
                <thead>
                    <tr><th>Stat Name</th><th>Value</th></tr>
                </thead>
                <tbody>
                    <?php foreach ($stats as $stat_name => $stat_value): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($stat_name); ?></td>
                            <td><?php echo htmlspecialchars(is_scalar($stat_value) ? $stat_value : json_encode($stat_value)); ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <br>
        <?php elseif (!$dataError): // Only show if no major data error occurred ?>
            <p>Select a player to view their stats for the <?php echo htmlspecialchars($selected_mode); ?> mode.</p>
        <?php endif; ?>

        <p>Last update: <?php echo $lastUpdated; ?></p>

    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
