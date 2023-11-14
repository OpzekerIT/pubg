<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
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
        <h2>Match Stats</h2>
        <?php
            include './config/config.php';

            $players_matches = json_decode(file_get_contents('./data/player_matches.json'), true);

            // Display buttons for each player
            echo "<form method='get' action=''>";
            foreach ($players_matches as $player_data) {
                if (isset($player_data['playername'])) {
                    $player_name = $player_data['playername'];
                    echo "<button type='submit' name='selected_player' value='$player_name' class='btn'>$player_name</button>";
                }
            }
            
            echo "</form><br>";

            $selected_player = $_GET['selected_player'] ?? $players_matches[0]['playername'];
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
            // Display the player's match stats
            foreach ($players_matches as $player_data) {
                if (isset($player_data['playername']) && $player_data['playername'] === $selected_player) {
                    echo "<h2>Recent Matches for $selected_player</h2>";
                    echo "<table border='1' class='sortable'>";
                    echo "<tr><th>Match Date</th><th>Game Mode</th><th>Match Type</th><th>Map</th><th>Kills</th><th>Damage Dealt</th><th>Time Survived</th><th>win Place</th></tr>";
                    foreach ($player_data['player_matches'] as $match) {
                        $date = new DateTime($match['createdAt']);
                        $date->modify('+2 hours');
                        $formattedDate = $date->format('m-d H:i:s');

                        $matchType = $match['matchType'];
                        $gameMode = $match['gameMode'];
                        $mapName = isset($mapNames[$match['mapName']]) ? $mapNames[$match['mapName']] : $match['mapName'];
                        $kills = $match['stats']['kills'];
                        $damage = number_format($match['stats']['damageDealt'], 0, '.', '');
                        $timeSurvived = $match['stats']['timeSurvived'];
                        $winPlace = $match['stats']['winPlace'];
                        echo "<tr><td>$formattedDate</td><td>$gameMode</td><td>$matchType</td><td>$mapName</td><td>$kills</td><td>$damage</td><td>$timeSurvived</td><td>$winPlace</td></tr>";
                    }
                    echo "</table><br>";

                }
            }
        ?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
