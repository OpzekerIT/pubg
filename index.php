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
            <h2>Latest Matches</h2>

            <table>
                
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

                    foreach ($lastMatches as $match) {
                        $matchid = $match['id'];

                        echo "<tr>
            <td><a href='matchinfo.php?matchid=$matchid'>" . $match['playername'] . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . $match['gameMode'] . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . $match['matchType'] . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . (isset($mapNames[$match['mapName']]) ? $mapNames[$match['mapName']] : $match['mapName']) . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . $match['stats']['kills'] . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . number_format($match['stats']['damageDealt'], 0, '.', '') . "</a></td>
            <td><a href='matchinfo.php?matchid=$matchid'>" . $match['stats']['winPlace'] . "</a></td>

        </tr>";
                    } ?>
               
            </table>
            <h2>Clan Info</h2>
            <?php


           //CLANINFO
            $clanInfoPath = './data/claninfo.json';
            $clanmembersfile = './config/clanmembers.json';
            $clanmembers = json_decode(file_get_contents($clanmembersfile), true);
            if (file_exists($clanInfoPath)) {
                $clan = json_decode(file_get_contents($clanInfoPath), true);
                if (isset($clan) && !empty($clan)) {
                    echo "<table>";
                    echo "<tr><th>Attribute</th><th>Value</th></tr>";
                    foreach ($clanmembers['clanMembers'] as $value) {
                        echo "<tr><td><a href='latestmatches.php?selected_player=" . htmlspecialchars($value) . "'>name</a></td><td><a href='latestmatches.php?selected_player=" . htmlspecialchars($value) . "'>" . htmlspecialchars($value) . "</a></td></tr>";
                    }
                    foreach ($clan as $key => $value) {
                        if($key == 'updated'){
                            continue;
                        }
                        echo "<tr><td>" . htmlspecialchars($key) . "</td><td>" . htmlspecialchars($value) . "</td></tr>";
                    }


                    echo "</table>";
                } else {
                    echo "<p>No clan attributes available</p>";
                }
            } else {
                echo "<p>Clan info file missing</p>";
            }
            ?>


        </section>
    </main>


    <?php include './includes/footer.php'; ?>
</body>

</html>