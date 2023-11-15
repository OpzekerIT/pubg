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
usort($allMatches, function ($a, $b) {
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
            <h2>Match info</h2>




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
            // Check if a match ID is provided in the GET request
            if (isset($_GET['matchid'])) {
                $matchId = $_GET['matchid'];
                $filename = "data/matches/" . $matchId . ".json";

                // Check if the JSON file for the given match ID exists
                if (file_exists($filename)) {
                    // Read and decode the JSON file
                    $jsonData = json_decode(file_get_contents($filename), true);
                    $matchinfo = $jsonData['data']['attributes'];
                    $matchdata = $jsonData['data'];
                    echo "<table class='sortable'><tr><th>matchType</th><th>gameMode</th><th>duration</th><th>gameMode</th><th>mapName</th><th>createdAt</th><th>id</th></tr>";
                    echo "<tr>";
                    echo "<td>" . htmlspecialchars($matchinfo['matchType']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['gameMode']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['duration']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['gameMode']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['mapName']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['createdAt']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchdata['id']) . "</td>";
                    echo "</tr>";

                    echo "</table>";


                    echo "<table class='sortable'>";
                    echo "<tr>
                            <th>Player Name</th>
                            <th>Kills</th>
                            <th>Damage Dealt</th>
                            <th>Time Survived</th>
                            <th>Rank</th>
                            <th>Revives</th>
                            <th>Longest Kill</th>
                            <th>DBNOs</th>
                            <th>Headshot Kills</th>
                            <th>Assists</th>
                        </tr>";

                    foreach ($jsonData['included'] as $includedItem) {
                        if ($includedItem['type'] == "participant") {
                            $playerStats = $includedItem['attributes']['stats'];
                            echo "<tr>";
                            echo "<td>" . htmlspecialchars($playerStats['name']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['kills']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['damageDealt']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['timeSurvived']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['winPlace']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['revives']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['longestKill']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['DBNOs']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['headshotKills']) . "</td>";
                            echo "<td>" . htmlspecialchars($playerStats['assists']) . "</td>";
                            echo "</tr>";
                        }
                    }
                    echo "</table>";

                } else {
                    echo "JSON file not found for the given match ID.";
                }
            } else {
                echo "No match ID provided.";
            }
            ?>

            </table>



        </section>
    </main>


    <?php include './includes/footer.php'; ?>
</body>

</html>