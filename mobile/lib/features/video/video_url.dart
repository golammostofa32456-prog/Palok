/// Cloudinary ভিডিও URL ছোট করে (পোর্ট্রেট, H.264)।
/// অন্য URL (demo/asset) হলে অপরিবর্তিত ফেরত দেয়।
String optimizeVideoUrl(String url) {
  const marker = '/video/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) {
    return url;
  }
  // আগে থেকে transformation থাকলে আবার বসাবে না
  if (url.contains('${marker}c_limit') || url.contains('${marker}q_auto')) {
    return url;
  }
  return url.replaceFirst(
    marker,
    '${marker}c_limit,w_540,q_auto,f_mp4,vc_h264/',
  );
}
