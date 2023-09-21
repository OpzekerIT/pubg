<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
?>

<?php //include './includes/ratelimiter.php'; ?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DTCH - PUBG Clan - User Stats</title>
    <link rel="stylesheet" href="./includes/styles.css">
</head>
<body>

<?php include './includes/navigation.php'; ?>

<main>
    <section>
        <h2>User Stats</h2>
        <?php
include './config/config.php';


$headers = array(
    'Authorization: Bearer ' . $apiKey,
    'Accept: application/vnd.api+json'
);

$selected_mode = isset($_POST['game_mode']) ? $_POST['game_mode'] : 'squad';

// Form to select game mode
echo "<form method='post' action=''>
        <input type='submit' name='game_mode' value='solo'>
        <input type='submit' name='game_mode' value='duo'>
        <input type='submit' name='game_mode' value='squad'>
      </form><br>";

// Buttons for each player
echo "<form method='post' action=''>";
foreach ($clanmembers as $player) {
    echo "<button type='submit' name='selected_player' value='$player'>$player</button>";
}
echo "</form><br>";

$selected_player = $_POST['selected_player'] ?? $clanmembers[0];

// Retrieve user IDs
$players_url = "https://api.pubg.com/shards/steam/players?filter[playerNames]=$selected_player";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $players_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
$players_response = curl_exec($ch);
curl_close($ch);
$players_data = json_decode($players_response, true);

if (isset($players_data['data'])) {
    $player = $players_data['data'][0];
    $player_id = $player['id'];
    $player_name = $player['attributes']['name'];

    // Retrieve lifetime stats
    $lifetime_url = "https://api.pubg.com/shards/steam/players/$player_id/seasons/lifetime?filter[gamepad]=false";
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $lifetime_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    $lifetime_response = curl_exec($ch);
    curl_close($ch);
    $lifetime_data = json_decode($lifetime_response, true);

    if (isset($lifetime_data['data']['attributes']['gameModeStats'][$selected_mode])) {
        $stats = $lifetime_data['data']['attributes']['gameModeStats'][$selected_mode];
        echo "<h2>" . ucfirst($selected_mode) . " Lifetime Stats for $player_name</h2>";
        echo "<table border='1'>";
        echo "<tr><th>Stat Name</th><th>Value</th></tr>";
        foreach ($stats as $stat_name => $stat_value) {
            echo "<tr><td>$stat_name</td><td>$stat_value</td></tr>";
        }
        echo "</table><br>";
    }
} else {
    echo "No player data available.";
}
?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
