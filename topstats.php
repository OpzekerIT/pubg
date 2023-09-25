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

            $players_data = json_decode(file_get_contents('./data/player_lifetime_data.json'), true);
            $selected_mode = isset($_POST['game_mode']) ? $_POST['game_mode'] : 'squad';

            // Form to select game mode
            echo "<form method='post' action=''>
                    <input type='submit' name='game_mode' value='solo' class='btn'>
                    <input type='submit' name='game_mode' value='duo' class='btn'>
                    <input type='submit' name='game_mode' value='squad' class='btn'>
                  </form><br>";

            // Displaying top 10 comparisons for each attribute
            $attributes = ['dBNOs', 'damageDealt', 'roadKills', 'teamKills','headshotKills','roundMostKills','kills','wins','top10s'];
            foreach ($attributes as $attribute) {
                echo "<h3>Top 10 $attribute</h3>";
                uasort($players_data[$selected_mode], function ($a, $b) use ($attribute) {
                    $account_id_a = array_key_first($a);
                    $account_id_b = array_key_first($b);
                    return $b[$account_id_b][$attribute] <=> $a[$account_id_a][$attribute]; // Sort in descending order
                });
                
                echo "<table border='1'>";
                echo "<tr><th>Player</th><th>$attribute</th></tr>";
                $count = 0;
                foreach ($players_data[$selected_mode] as $player_name => $player_details) {
                    if ($count++ >= 10) break; // Limit to top 10 players
                    $account_id = array_key_first($player_details);
                    echo "<tr><td>$player_name</td><td>{$player_details[$account_id][$attribute]}</td></tr>";
                }
                echo "</table><br>";
            }

            echo "Last update " ;
            echo $players_data['updated'];
        ?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>