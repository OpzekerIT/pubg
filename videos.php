<?php
$ogDescription = "Bekijk alle video's";

// Scan the media/videos directory for mp4 files
$videosDir = __DIR__ . '/media/videos';
$allFiles = scandir($videosDir);
$videoFiles = array_filter($allFiles, function($file) use ($videosDir) {
    return is_file($videosDir . '/' . $file) && strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'mp4';
});

// Build array with creation time and sort by creation date descending
$videoData = [];
foreach ($videoFiles as $file) {
    $path = $videosDir . '/' . $file;
    $videoData[] = [
        'filename' => $file,
        'ctime' => filectime($path)
    ];
}
usort($videoData, function($a, $b) {
    return $b['ctime'] - $a['ctime'];
});
?>

<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; ?>

<body>
    <?php include './includes/navigation.php'; ?>
    <?php include './includes/header.php'; ?>
    <main>
        <section>
            <h2>Videos</h2>

            <?php if (!empty($videoData)): ?>
                <div class="videos-container">
                    <?php foreach ($videoData as $video): ?>
                        <div class="video-item">
                            <video controls>
                                <source src="media/videos/<?php echo htmlspecialchars($video['filename']); ?>" type="video/mp4">
                                Your browser does not support the video tag.
                            </video>
                            <p><?php echo pathinfo($video['filename'], PATHINFO_FILENAME); ?></p>
                            <p><?php echo date('d-m-Y H:i', $video['ctime']); ?></p>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php else: ?>
                <p>No videos found.</p>
            <?php endif; ?>

        </section>
    </main>

    <?php include './includes/footer.php'; ?>
</body>
</html>