<?php
// --- Configuration and Data Processing ---
$dataPointsPerPlayer = [];
$chartData = [];
$encodedChartData = '[]'; // Default to empty JSON array
$dataError = '';
$directory = 'data/killstats';

// Check if the directory exists
if (!is_dir($directory)) {
    $dataError = "The directory '$directory' does not exist or is not accessible.";
} else {
    // Attempt to open the directory
    $handle = @opendir($directory); // Use @ to suppress default warning on failure
    if ($handle === false) {
        $dataError = "Could not open the directory '$directory'. Check permissions.";
    } else {
        // Loop through the directory
        while (false !== ($entry = readdir($handle))) {
            // Skip '.' and '..' and non-JSON files
            if ($entry === '.' || $entry === '..' || pathinfo($entry, PATHINFO_EXTENSION) !== 'json') {
                continue;
            }

            $filepath = $directory . '/' . $entry;
            $content = @file_get_contents($filepath); // Use @ to suppress warning on failure

            if ($content === false) {
                // Log or handle file read error if necessary, maybe skip the file
                error_log("Could not read file: " . $filepath);
                continue;
            }

            // Decode JSON data to PHP array
            $jsonArray = json_decode($content, true);

            // Basic validation of JSON structure
            if (is_array($jsonArray) && isset($jsonArray['stats']['playername'], $jsonArray['created'], $jsonArray['winplace'])) {
                $playername = $jsonArray['stats']['playername'];
                $winplace = $jsonArray['winplace'];
                $createdTimestamp = $jsonArray['created'];

                // Process the date
                try {
                    $date = new DateTime($createdTimestamp);
                    $label = $date->format('m-d'); // Month-Day format

                    // Initialize player array if not existing
                    if (!isset($dataPointsPerPlayer[$playername])) {
                        $dataPointsPerPlayer[$playername] = [];
                    }

                    // Add to dataPoints for this player
                    $dataPointsPerPlayer[$playername][] = [
                        "y" => $winplace,
                        "label" => $label
                    ];
                } catch (Exception $e) {
                    // Log or handle date parsing error
                    error_log("Could not parse date '$createdTimestamp' in file: " . $filepath);
                    continue;
                }
            } else {
                 // Log or handle invalid JSON structure
                 error_log("Invalid JSON structure or missing keys in file: " . $filepath);
                 continue;
            }
        }
        closedir($handle);

        // Prepare data for the chart if processing was successful
        if (empty($dataError) && !empty($dataPointsPerPlayer)) {
            foreach ($dataPointsPerPlayer as $player => $dataPoints) {
                // Sort data points by label (date) for each player
                usort($dataPoints, function($a, $b) {
                    return strcmp($a['label'], $b['label']);
                });

                $chartData[] = [
                    'type' => 'line',
                    'showInLegend' => true,
                    'legendText' => htmlspecialchars($player), // Escape player name for legend
                    'dataPoints' => $dataPoints
                ];
            }
            // Encode the final chart data
            $encodedChartData = json_encode($chartData, JSON_NUMERIC_CHECK);
            if ($encodedChartData === false) {
                $dataError = "Failed to encode chart data into JSON.";
                $encodedChartData = '[]'; // Reset to empty array on encoding failure
            }
        } elseif (empty($dataError)) {
             $dataError = "No valid data found in '$directory' to generate chart.";
        }
    }
}

// Note: The original $dataPoints array with days of the week was unused, so it's removed.
?>
<!DOCTYPE HTML>
<html>
<head>
    <meta charset="UTF-8">
    <title>Player Win Place Over Time</title>
    <script src="https://cdn.canvasjs.com/canvasjs.min.js"></script>
    <style>
        body { font-family: sans-serif; }
        .chart-container { height: 400px; width: 95%; margin: 20px auto; }
        .error-message { color: red; text-align: center; margin-top: 20px; }
    </style>
</head>
<body>

<?php if ($dataError): ?>
    <p class="error-message"><?php echo htmlspecialchars($dataError); ?></p>
<?php else: ?>
    <div id="chartContainer" class="chart-container"></div>
    <script>
        window.onload = function () {
            // Use the PHP-generated JSON data
            var playerData = <?php echo $encodedChartData; ?>;

            if (playerData && playerData.length > 0) {
                var chart = new CanvasJS.Chart("chartContainer", {
                    animationEnabled: true,
                    theme: "light2", // Optional theme
                    title: {
                        text: "Win Place by Player / Per Day"
                    },
                    axisY: {
                        title: "Win Place",
                        reversed: true, // Lower win place is better
                        interval: 1 // Show integer ranks
                    },
                     axisX: {
                        title: "Date (MM-DD)",
                        // Consider adding valueFormatString if labels become too crowded
                    },
                    legend: {
                        cursor: "pointer",
                        verticalAlign: "center",
                        horizontalAlign: "right",
                        dockInsidePlotArea: false,
                        itemclick: function (e) {
                            // Toggle data series visibility on legend item click
                            if (typeof(e.dataSeries.visible) === "undefined" || e.dataSeries.visible) {
                                e.dataSeries.visible = false;
                            } else {
                                e.dataSeries.visible = true;
                            }
                            e.chart.render();
                        }
                    },
                    data: playerData // This will be an array of data series, one per player
                });
                chart.render();
            } else {
                 // Display a message if no data is available to chart
                 document.getElementById("chartContainer").innerHTML = '<p style="text-align:center; padding-top: 50px;">No chart data available.</p>';
            }
        }
    </script>
<?php endif; ?>

</body>
</html>