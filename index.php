<?php
// Read the JSON file
$jsonData = file_get_contents('data/player_matches.json');
$playersData = json_decode($jsonData, true);

// Combine matches from all players
$allMatches = [];
foreach ($playersData as $player) {
    foreach ($player['player_matches'] as $match) {
        $match['playername'] = $player['playername'];  // Add playername to each match for reference
        $allMatches[] = $match;
    }
}

// Sort matches by createdAt date
usort($allMatches, function($a, $b) {
    return strtotime($b['createdAt']) - strtotime($a['createdAt']);
});

// Get the last 5 matches
$lastMatches = array_slice($allMatches, 0, 8);

?>

<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; ?>
<body>
<?php include './includes/navigation.php'; ?>

    <header>
    <img src="./images/banner2.png" alt="banner" class="banner">
    </header>
    
<main>
    <section>
        <h2>Latest Matches</h2>

        <table>
    <thead>
        <tr>
            <!-- <th>Match Date</th> -->
            <th>Player Name</th>
            <th>Mode</th>
            <th>Type</th>
            <th>Map</th>
            <th>Kills</th>
            <th>Damage</th>
            <th>Place</th>
        </tr>
    </thead>
    <tbody>
        <?php
        $mapNames = array(
            "Baltic_Main" => "Erangel",
            "Chimera_Main" => "Paramo",
            "Desert_Main" => "Miramar",
            "DihorOtok_Main" => "Vikendi",
            "Erangel_Main" => "Erangel",
            "Heaven_Main" => "Haven",
            "Kiki_Main" => "Deston",
            "Range_Main" => "Camp Jackal",
            "Savage_Main" => "Sanhok",
            "Summerland_Main" => "Karakin",
            "Tiger_Main" => "Taego"
        );

        foreach($lastMatches as $match) {
            ?>
            <tr>
            <!--    <td><?php echo date("Y-m-d", strtotime($match['createdAt'])); ?></td> -->
                <td><?php echo $match['playername']; ?></td>
                <td><?php echo $match['gameMode']; ?></td>
                <td><?php echo $match['matchType']; ?></td>
                <td><?php echo isset($mapNames[$match['mapName']]) ? $mapNames[$match['mapName']] : $match['mapName']; ?></td>
                <td><?php echo $match['stats']['kills']; ?></td>
                <td><?php echo number_format($match['stats']['damageDealt'], 0, '.', ''); ?></td>
                <td><?php echo $match['stats']['winPlace']; ?></td>
            </tr>
            <?php
        }
        ?>
    </tbody>
</table>

        <p>Join us on our Discord:</p>
        <a href="https://discord.gg/wMXsB3ZmNA" target="_blank" rel="noopener noreferrer">
            <img src="./media/discordlogo.png" alt="Discord Logo" class="discord-logo">
        </a>
    </section>
</main>


    <?php include './includes/footer.php'; ?>
</body>
</html>
