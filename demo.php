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

$dataPoints = array();
$directory = './data/killstats';

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
            
            // Process the date
            $date = new DateTime($jsonArray['created']);
            $label = $date->format('m-d'); // Month-Day format
            
            // Add to dataPoints
            $dataPoints[] = array(
                "y" => $jsonArray['winplace'],
                "label" => $label
            );
        }
    }
    closedir($handle);
}

// Output the array
print_r($dataPoints);
?>


<!DOCTYPE HTML>
<html>
<head>
<script>
window.onload = function () {
 
var chart = new CanvasJS.Chart("chartContainer", {
	title: {
		text: "Winrato last month"
	},
	axisY: {
		title: "wins"
	},
	data: [{
		type: "line",
		dataPoints: <?php echo json_encode($dataPoints, JSON_NUMERIC_CHECK); ?>
	}]
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