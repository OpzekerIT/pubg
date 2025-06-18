<?php
$ogDescription = "Get in-depth insights into recent PUBG matches. Discover detailed match information including player stats, game modes, match types, and map names. Updated regularly to provide the latest and most comprehensive match data for PUBG enthusiasts.";
?>


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
    <?php
    include './includes/navigation.php';
    include './includes/header.php';
    ?>


    <main>
        <section>
            <h2>Match info</h2>




            <?php

            include './includes/mapsmap.php';
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


                    echo "<table class='sortable'><tr><th>matchType</th><th>gameMode</th><th>duration</th><th>mapName</th><th>createdAt</th><th>id</th></tr>";
                    echo "<tr>";
                    echo "<td>" . htmlspecialchars($matchinfo['matchType']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['gameMode']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['duration']) . "</td>";
                    echo "<td>" . htmlspecialchars(isset($mapNames[$matchinfo['mapName']]) ? $mapNames[$matchinfo['mapName']] : $matchinfo['mapName']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchinfo['createdAt']) . "</td>";
                    echo "<td>" . htmlspecialchars($matchdata['id']) . "</td>";
                    echo "</tr>";
                    echo "</table>";

                    $directory = 'data/killstats/';
                    $prefix = $matchdata['id'];
                    $files = glob($directory . $prefix . '*');

                    if (count($files) == 0) {
                        // Get current time
                        $currentTime = new DateTime();
                        $minutes = intval($currentTime->format('i'));

                        // Calculate minutes to next update
                        $minutesToNextUpdate = 30 - ($minutes % 30);
                        if ($minutesToNextUpdate === 30) {
                            // If it's exactly on the hour or half-hour, set the next update to 30 minutes
                            $minutesToNextUpdate = 0;
                        }

                        // Display the message
                        if ($minutesToNextUpdate > 0) {
                            echo "Check back in $minutesToNextUpdate minutes. Data is updated every half hour.";
                        } else {
                            echo "Data is updating, please check back shortly.";
                        }
                    } else {

                        echo "<table class='sortable'>";
                        echo "<tr>
                            <th>Player Name</th>
                            <th>humankills</th>
                            <th>HumanDmg </th>
                            <th>Kills</th>
                            <th>Total Damage</th>
                            <th>Rank</th>
                            <th>DBNOs</th>
                        </tr>";

                        foreach ($files as $file) {
                            $jsonData_individual_player = json_decode(file_get_contents($file), true);
                            $individualPlayerName = $jsonData_individual_player['stats']['playername'];

                            // Search for the player in $jsonData['included'] to find damageDealt
                            $damageDealt = 0;
                            foreach ($jsonData['included'] as $includedItem) {
                                if ($includedItem['type'] == "participant") {
                                    $playerStats = $includedItem['attributes']['stats'];
                                    if ($individualPlayerName == $playerStats['name']) {
                                        $damageDealt = $playerStats['damageDealt'];
                                        $rank = $playerStats['winPlace'];
                                        $DBNOs = $playerStats['DBNOs'];
                                        break;
                                    }
                                }
                            }

                            echo "<tr>";
                            echo "<td>" . htmlspecialchars($individualPlayerName) . "</td>";
                            echo "<td>" . htmlspecialchars($jsonData_individual_player['stats']['humankills']) . "</td>";
                            echo "<td>" . htmlspecialchars($jsonData_individual_player['stats']['HumanDmg']) . "</td>";
                            echo "<td>" . htmlspecialchars($jsonData_individual_player['stats']['kills']) . "</td>";
                            echo "<td>" . htmlspecialchars($damageDealt) . "</td>";
                            echo "<td>" . htmlspecialchars($rank) . "</td>";
                            echo "<td>" . htmlspecialchars($DBNOs) . "</td>";
                            echo "</tr>";
                        }
                        echo "</table>";
                    }
                    echo "<table class='sortable'>";
                    echo "<tr>
                            <th>Player Name</th>
                            <th>Sort</th>
                            <th>Kills</th>
                            <th>Damage Dealt</th>
                            <th>Time Survived</th>
                            <th>Rank</th>
                            <th>Revs</th>
                            <th>DBNOs</th>
                            <th>Assists</th>

                        </tr>";
                    foreach ($jsonData['included'] as $includedItem) {
                        if ($includedItem['type'] == "participant") {
                            $playerStats = $includedItem['attributes']['stats'];
                            if (substr($playerStats['playerId'], 0, 2) !== 'ai') {
                                // Create links for each stat
                                echo "<tr>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['name']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'> Human </a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['kills']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['HumanDmg']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['timeSurvived']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['winPlace']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['revives']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['DBNOs']) . "</a></td>";
                                echo "<td><a href='https://www.pubg-meta.com/player-stats/steam/" . urlencode($playerStats['name']) . "' target='_blank'>" . htmlspecialchars($playerStats['assists']) . "</a></td>";
                                echo "</tr>";
                            } else {
                                // Display without link
                                echo "<tr>";
                                echo "<td>" . htmlspecialchars($playerStats['name']) . "</td>";
                                echo "<td>Bot</a></td>";
                                echo "<td>" . htmlspecialchars($playerStats['kills']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['damageDealt']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['timeSurvived']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['winPlace']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['revives']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['DBNOs']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['headshotKills']) . "</td>";
                                echo "<td>" . htmlspecialchars($playerStats['assists']) . "</td>";
                                echo "</tr>";
                            }
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