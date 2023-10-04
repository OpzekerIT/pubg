<?php
// Read the JSON file
$jsonData = file_get_contents('data/player_matches.json');
$playersData = json_decode($jsonData, true);

// Function to get the last 5 matches for a player
function getLastMatches($player) {
    return array_slice($player['player_matches'], -5);
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DTCH - PUBG Clan</title>
    <link rel="stylesheet" href="./includes/styles.css">
</head>
<body>
<?php include './includes/navigation.php'; ?>

    <header>
        <h1>Welcome to DTCH - PUBG Clan</h1>
    </header>
    
<main>
    <section>

    <table border="1">
    <thead>
        <tr>
            <th>Match Date</th>
            <th>Player Name</th>
            <th>Game Mode</th>
            <th>MatchType</th>
            <th>Map</th>
            <th>Kills</th>
            <th>Damage Dealt</th>
            <th>Time Survived</th>
            <th>Win Place</th>
        </tr>
    </thead>
    <tbody>
        <?php
        foreach($playersData as $player) {
            $matches = getLastMatches($player);
            foreach($matches as $match) {
                ?>
                <tr>
                    <td><?php echo date("Y-m-d", strtotime($match['createdAt'])); ?></td>
                    <td><?php echo $player['playername']; ?></td>
                    <td><?php echo $match['gameMode']; ?></td>
                    <td><?php echo $match['matchType']; ?></td>
                    <td><?php echo $match['mapName']; ?></td>
                    <td><?php echo $match['stats']['kills']; ?></td>
                    <td><?php echo $match['stats']['damageDealt']; ?></td>
                    <td><?php echo gmdate("H:i:s", $match['stats']['timeSurvived']); ?></td>
                    <td><?php echo $match['stats']['winPlace']; ?></td>
                </tr>
                <?php
            }
        }
        ?>
    </tbody>
</table>
        <h2>Welcome to DTCH - PUBG Clan</h2>
        <p>Join us on our Discord:</p>
        <a href="https://discord.gg/wMXsB3ZmNA" target="_blank" rel="noopener noreferrer">
            <img src="./media/discordlogo.png" alt="Discord Logo" class="discord-logo">
        </a>
    </section>
</main>


    <?php include './includes/footer.php'; ?>
</body>
</html>
