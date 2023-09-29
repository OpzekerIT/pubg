<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DTCH - PUBG Clan - Match Stats</title>
    <link rel="stylesheet" href="./includes/styles.css">
    <script src="./lib/sorttable.js"></script>
</head>

<body>

    <?php include './includes/navigation.php'; ?>

    <main>
        <section>
            <h2>Player Stats past 14 days</h2>
            <?php
            include './config/config.php';

            $players_matches = json_decode(file_get_contents('./data/player_last_stats.json'), true);

            echo "<table border='1' class='sortable'>";
            echo "<tr>
                <th>Playername</th>
                <th>Deaths</th>
                <th>Kills</th>
                <th>Human Kills</th>
                <th>Matches</th>
                <th>K/D (Human)</th>
                <th>K/D (All)</th>
            </tr>";

            foreach ($players_matches as $player_datas) {
                

                foreach ($player_datas as $player_data) {
                    if (!isset($player_data['playername']) || is_null($player_data['playername'])) {
                        continue; // Skip this iteration and move to the next
                    }
                    $player_name = $player_data['playername'];
                    $deaths = number_format($player_data['deaths'], 2, ',', '');
                    $kills = number_format($player_data['kills'], 2, ',', '');
                    $humankills = number_format($player_data['humankills'], 2, ',', '');
                    $matches = $player_data['matches'];
                    $KD_H = ($player_data['KD_H'] == "Infinity") ? "∞" : number_format($player_data['KD_H'], 2, ',', '');
                    $KD_ALL = ($player_data['KD_ALL'] == "Infinity") ? "∞" : number_format($player_data['KD_ALL'], 2, ',', '');

                    echo "<tr>
                    <td>$player_name</td>
                    <td>$deaths</td>
                    <td>$kills</td>
                    <td>$humankills</td>
                    <td>$matches</td>
                    <td>$KD_H</td>
                    <td>$KD_ALL</td>
                </tr>";
                }

                echo "</table>";
            }


            echo "Last update: ";
            foreach ($players_matches as $player_data) {
                if (isset($player_data['updated'])) {
                    echo $player_data['updated'];
                    break; // Once found, exit the loop
                }
            }



            ?>
        </section>
    </main>

    <?php include './includes/footer.php'; ?>

</body>

</html>