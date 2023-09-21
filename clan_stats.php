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
    <title>DTCH - PUBG Clan - Clan Stats</title>
    <link rel="stylesheet" href="./includes/styles.css">
</head>
<body>

<?php include './includes/navigation.php'; ?>

<main>
    <section>
        <h2>Clan Stats</h2>
        <?php
            include './config/config.php';

            // Load clan data from claninfo.json
            $clanInfoPath = './data/claninfo.json';
            if (file_exists($clanInfoPath)) {
                $clan = json_decode(file_get_contents($clanInfoPath), true);
                if (isset($clan) && !empty($clan)) {
                    echo "<table>";
                    echo "<tr><th>Attribute</th><th>Value</th></tr>";
                    foreach ($clan as $key => $value) {
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
