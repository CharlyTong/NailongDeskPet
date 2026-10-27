把桌宠的序列帧素材放在这个文件夹里，文件命名约定：

  idle_0.png  idle_1.png  idle_2.png  ...   待机
  walk_0.png  walk_1.png  ...              走路（左右共用，代码自动镜像）
  happy_0.png happy_1.png ...               被点击后的开心反应
  drag_0.png  drag_1.png  ...               被拖拽时的动作
  fall_0.png  fall_1.png  ...               掉落时的动作

要求：透明背景 PNG；每个动作的帧数要与 SpriteConfig.json 里声明的 frames 一致。
素材没放进来也没关系，程序会用内置的占位色块小猫运行。
