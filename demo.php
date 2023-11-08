<?php
 
$dataPoints = array(
	array("y" => 25, "label" => "Sunday"),
	array("y" => 15, "label" => "Monday"),
	array("y" => 25, "label" => "Tuesday"),
	array("y" => 5, "label" => "Wednesday"),
	array("y" => 10, "label" => "Thursday"),
	array("y" => 0, "label" => "Friday"),
	array("y" => 20, "label" => "Saturday")
);
 
?>
<?php

$dataPointsPerPlayer = [];
$directory = 'data/killstats';

// Check if the directory exists
if (!is_dir($directory)) {
    die("The directory $directory does not exist");
}

// Open the directory
if ($handle = opendir($directory)) {
    // Loop through the directory
    while (false !== ($entry = readdir($handle))) {
        if ($entry !== '.' && $entry !== '..') {
            // Read each file
            $filepath = $directory . '/' . $entry;
            $content = file_get_contents($filepath);
            
            // Decode JSON data to PHP array
            $jsonArray = json_decode($content, true);
            
            // Extract playername
            $playername = $jsonArray['stats']['playername'];
            // Process the date
            $date = new DateTime($jsonArray['created']);
            $label = $date->format('m-d'); // Month-Day format
            
            // Initialize player array if not existing
            if (!isset($dataPointsPerPlayer[$playername])) {
                $dataPointsPerPlayer[$playername] = [];
            }
            
            // Add to dataPoints for this player
            $dataPointsPerPlayer[$playername][] = array(
                "y" => $jsonArray['winplace'],
                "label" => $label
            );
        }
    }
    closedir($handle);
}

// Now, $dataPointsPerPlayer is an array that contains an array of data points for each player
// You can access the data for a specific player like this:
// $playerData = $dataPointsPerPlayer['Lanta01'];

// Output the array for debugging purposes
// At the end of your PHP script, where you previously printed the array
// Instead, we will encode the $dataPointsPerPlayer array into JSON
$chartData = [];
foreach ($dataPointsPerPlayer as $player => $dataPoints) {
    $chartData[] = [
        'type' => 'line',
        'showInLegend' => true,
        'legendText' => $player,
        'dataPoints' => $dataPoints
    ];
}

// Store the JSON encoded data in a PHP variable
$encodedChartData = json_encode($chartData, JSON_NUMERIC_CHECK);

// You can then pass this to your JavaScript code like this
echo "<script>var playerData = $encodedChartData;</script>";


?>



<!DOCTYPE HTML>
<html>
<head>
<script>
window.onload = function () {

    var chart = new CanvasJS.Chart("chartContainer", {
        title: {
            text: "Win rate by Player"
        },
        axisY: {
            title: "Win Place"
        },
        legend: {
            cursor: "pointer",
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

}
</script>

</head>
<body>
<div id="chartContainer" style="height: 370px; width: 100%;"></div>
<script src="https://cdn.canvasjs.com/canvasjs.min.js"></script>
</body>
</html>   