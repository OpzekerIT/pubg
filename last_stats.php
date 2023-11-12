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
            <h2>Player Stats past month</h2>
            <?php
            include './config/config.php';

            $players_matches = json_decode(file_get_contents('./data/player_last_stats.json'), true);

            foreach ($players_matches as $key => $player_datas) {
                if ($key == 'updated') {
                    continue;
                }

                echo "<br>";
                if($key == 'all'){
                echo "Stats for $key (minimal 20 matches)";
                }else{
                    echo "Stats for $key (minimal 8 matches)";
                }
                echo "<table border='1' class='sortable'>";
                echo "<tr>
                    <th>Player</th>
                    <th>Win %</th>
                    <th>K/D Human</th>
                    <th>K/D All</th>
                    <th>Kills</th>
                    <th>Human Kills</th>
                    <th>Mtchs</th>
                    <th>Wins</th>
                    <th>Deaths</th>
                    <th>Win % change</th>

                    
                </tr>";
                foreach ($player_datas as $player_data) {
                    if (!isset($player_data['playername']) || is_null($player_data['playername'])) {
                        continue; // Skip this iteration and move to the next
                    }
                    if ($player_data['matches'] < 8){
                        continue;
                    }
                    if ($key == 'all' && $player_data['matches'] < 20) {
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

                    if ($originalChange < 0) {
                        $imagePath = 'images\red.png';
                    } elseif ($change > 0) {
                        $imagePath = 'images\green.png';
                    } else {
                        $imagePath = 'images\equal.png';
                    }



                    echo "<tr>
                    <td>$player_name</td>
                    <td>$winratio</td>
                    <td>$KD_H</td>
                    <td>$KD_ALL</td>
                    <td>$kills</td>
                    <td>$humankills</td>
                    <td>$matches</td>
                    <td>$wins</td>
                    <td>$deaths</td>
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