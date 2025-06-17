<?php
$ogDescription = "Bekijk alle video's";

// Scan the media/videos directory for mp4 files
$videosDir = __DIR__ . '/media/videos';
$allFiles = scandir($videosDir);
$videoFiles = array_filter($allFiles, function($file) use ($videosDir) {
    return is_file($videosDir . '/' . $file) && strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'mp4';
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

            <?php if (!empty($videoFiles)): ?>
                <div class="videos-container">
                    <?php foreach ($videoFiles as $video): ?>
                        <div class="video-item">
                            <video controls>
                                <source src="media/videos/<?php echo htmlspecialchars($video); ?>" type="video/mp4">
                                Your browser does not support the video tag.
                            </video>
                            <p><?php echo htmlspecialchars($video); ?></p>
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