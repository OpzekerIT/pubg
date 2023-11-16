<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; ?>

<body>

    <?php 
    include './includes/navigation.php';
    include './config/config.php';
    ?>
    <header>
        <img src="./images/banner2.png" alt="banner" class="banner">
    </header>
    <main>
        <section>
            <h2>Clan Stats</h2>
            <?php
            

            // Load clan data from claninfo.json
            $clanInfoPath = './data/claninfo.json';
            $clanmembersfile = './config/clanmembers.json';
            $clanmembers = json_decode(file_get_contents($clanmembersfile), true);
            if (file_exists($clanInfoPath)) {
                $clan = json_decode(file_get_contents($clanInfoPath), true);
                if (isset($clan) && !empty($clan)) {
                    echo "<table>";
                    echo "<tr><th>Attribute</th><th>Value</th></tr>";
                    foreach ($clan as $key => $value) {
                        echo "<tr><td>" . htmlspecialchars($key) . "</td><td>" . htmlspecialchars($value) . "</td></tr>";
                    }
                    foreach ($clanmembers['clanMembers'] as $value) {
                        echo "<tr><td><a href='latestmatches.php?selected_player=" . htmlspecialchars($value) . "'>name</a></td><td><a href='latestmatches.php?selected_player=" . htmlspecialchars($value) . "'>" . htmlspecialchars($value) . "</a></td></tr>";
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