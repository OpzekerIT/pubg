<?php
$ogDescription = "Explore detailed player statistics over the past month including win percentages, K/D ratios in human and all-player categories, total kills, and more. Delve into stats for various match types like Intense, Casual, Official, Custom, and Ranked, and see how players have fared in a minimum number of matches. Stay informed with the latest updates on player performance.";
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
            <h2>Player Stats past Quarter</h2>
            <?php
            include './config/config.php';
            $clanmembers = json_decode(file_get_contents('./config/clanmembers.json'), true);
            $alts = $clanmembers['alts'];
            $players_matches = json_decode(file_get_contents('./data/player_last_stats.json'), true);

            foreach ($players_matches as $key => $player_datas) {
                if ($key == 'updated') {
                    continue;
                }
                if ($key == 'all') {
                    continue;
                }

                echo "<br>";
                // if ($key == 'all') {
                //     echo "Stats for $key (minimal 25 matches)";
                // }
                if ($key == 'clan_casual') {
                    echo "Stats for $key (minimal 18 matches) - Clan casual min 2 clan players per match";
                }
                if ($key == 'Intense') {
                    echo "Stats for $key (minimal 18 matches)";
                }
                if ($key == 'Casual') {
                    echo "Stats for $key (minimal 18 matches)";
                }
                if ($key == 'official') {
                    echo "Stats for $key (minimal 18 matches)";
                }
                if ($key == 'custom') {
                    echo "Stats for $key (minimal 8 matches)";
                }
                if ($key == 'Ranked') {
                    echo "Stats for $key (minimal 8 matches)";
                }
                echo "<table border='1' class='sortable'>";
                echo "<tr>
                    <th>Player</th>
                    <th>Win %</th>
                    <th>AHD</th>
                    <th>K/D Human</th>
                    <th>Human Kills</th>
                    <th>K/D All</th>
                    <th>Kills</th>
                    <th>Mtchs</th>
                    <th>Wins</th>
                    <th>Deaths</th>
                    <th>Win % change</th>

                    
                </tr>";
                foreach ($player_datas as $player_data) {
                    if (!isset($player_data['playername']) || is_null($player_data['playername'])) {
                        continue; // Skip this iteration and move to the next
                    }
                    if (in_array($player_data['playername'], $alts)) {
                        continue; // Skip alt players
                    }
                    
                    if ($key == 'all' && $player_data['matches'] < 25) {
                        continue;
                    }
                    if ($key == 'clan_casual' && $player_data['matches'] < 18) {
                        continue;
                    }
                    if ($key == 'Intense' && $player_data['matches'] < 18) {
                        continue;
                    }
                    if ($key == 'Casual' && $player_data['matches'] < 18) {
                        continue;
                    }
                    if ($key == 'official' && $player_data['matches'] < 18) {
                        continue;
                    }
                    if ($key == 'custom' && $player_data['matches'] < 8) {
                        continue;
                    }
                    if ($key == 'Ranked' && $player_data['matches'] < 8) {
                        continue;
                    }

                    $player_name = $player_data['playername'];
                    $deaths = number_format($player_data['deaths'], 0, ',', '');
                    $kills = number_format($player_data['kills'], 0, ',', '');
                    $humankills = number_format($player_data['humankills'], 0, ',', '');
                    $matches = $player_data['matches'];
                    $KD_H =
                        !isset($player_data['KD_H']) || $player_data['KD_H'] === null
                        ? "null"
                        : ($player_data['KD_H'] == "Infinity"
                            ? "∞"
                            : (is_numeric($player_data['KD_H'])
                                ? number_format((float) $player_data['KD_H'], 2, ',', '')
                                : "0")); // or any other default string for non-numerical values
            

                    $KD_ALL =
                        !isset($player_data['KD_ALL']) || $player_data['KD_ALL'] === null
                        ? "null"
                        : ($player_data['KD_ALL'] == "Infinity"
                            ? "∞"
                            : (is_numeric($player_data['KD_ALL'])
                                ? number_format((float) $player_data['KD_ALL'], 2, ',', '')
                                : "0")); // or any other default string for non-numerical values
                    $wins = number_format($player_data['wins'], 0, ',', '');
                    $winratio = number_format($player_data['winratio'], 2, ',', '');
                    $originalChange = str_replace(',', '.', $player_data['change']); // replace comma with period
                    $change = floatval($originalChange);
                    $ahd = number_format($player_data['ahd'], 2, ',', '');

                    if ($originalChange < 0) {
                        $imagePath = 'images\red.png';
                    } elseif ($change > 0) {
                        $imagePath = 'images\green.png';
                    } else {
                        $imagePath = 'images\equal.png';
                    }



                    echo "<tr>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$player_name</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$winratio</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$ahd</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$KD_H</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$humankills</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$KD_ALL</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$kills</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$matches</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$wins</a></td>
                    <td><a href='latestmatches.php?selected_player=$player_name'>$deaths</a></td>
                    <td style='line-height: 17px;'><img src='$imagePath' alt='Change Indicator' style='vertical-align: middle;' width='17' height='17'/> $change </td>

                    
                </tr>";
                }

                echo "</table>";
            }

            foreach ($players_matches as $key => $update) {
                if ($key == 'updated') {
                    echo "Last update: $update ";

                }
            }





            ?>
        </section>
    </main>

    <?php include './includes/footer.php'; ?>

</body>

</html>
