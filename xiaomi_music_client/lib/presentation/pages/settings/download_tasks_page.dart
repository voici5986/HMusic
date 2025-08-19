import 'package:flutter/material.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('下载任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: onSurface.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onSurface.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '暂无下载任务',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '说明：\n\n'
                  '1. 单曲下载：\n'
                  '   - 在搜索结果或曲库条目右侧菜单中选择“下载到本地”即可创建单曲下载任务。\n\n'
                  '2. 合集/歌单下载：\n'
                  '   - 右上角设置菜单选择“从链接下载”，切换到“合集”标签，填好保存目录与歌单链接后提交。\n\n'
                  '3. 服务器端下载：\n'
                  '   - 所有下载任务都由服务器执行，下载完成后曲库会自动刷新。',
                  style: TextStyle(color: onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}








