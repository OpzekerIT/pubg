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
        <h2>Average User Stats</h2>
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

            $metrics = [
                'Kills' => 'kills',
                'Damage' => 'damageDealt',
                'Headshots' => 'headshotKills',
                'Wins' => 'wins',
                'Top10s' => 'top10s'
            ];

            echo "<table border='1' class='sortable'>";
            echo "<tr><th>Player</th>";
            foreach ($metrics as $display => $metric) {
                echo "<th>Average $display</th>";
            }
            echo "</tr>";

            foreach ($players_data[$selected_mode] as $player_name => $player_details) {
                $account_id = array_key_first($player_details);
                $stats = $player_details[$account_id];
                $totalGames = $stats['wins'] + $stats['losses']; // Wins + Losses

                echo "<tr><td>$player_name</td>";
                foreach ($metrics as $metric) {
                    $averageValue = ($totalGames > 0) ? round($stats[$metric] / $totalGames, 2) : 0;
                    echo "<td>$averageValue</td>";
                }
                echo "</tr>";
            }

            echo "</table><br>";
            echo "Last update " ;
            echo $players_data['updated'];
        ?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
