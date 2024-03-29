//
//  GameScene.swift
//  MarbleMaze
//
//  Created by J S on 2/15/24.
//

import AVFoundation
import CoreMotion
import SpriteKit

enum CollisionTypes: UInt32 {
    case player = 1
    case wall = 2
    case star = 4
    case vortex = 8
    case finish = 16
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var audioPlayer: AVAudioPlayer?
    var isGameOver = false
    var motionManager: CMMotionManager?
    var player: SKSpriteNode!
    let pink = UIColor(red: 252/255, green: 0/255, blue: 150/255, alpha: 1)
    var isInsideMode = true
    
    var levelLabel: SKLabelNode!
    var level = 1 {
        didSet {
            levelLabel.text = "Level: \(level)"
        }
    }
    
    var scoreLabel: SKLabelNode!
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var restartLabel: SKLabelNode!
    var outsideLabel: SKLabelNode!
    var insideLabel: SKLabelNode!
    
    override func didMove(to view: SKView) {
        createLabels()
        loadBackground(imageName: "purple-carpet")
        loadLevel(fileName: "level1")
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        view.scene?.scaleMode = .aspectFit
        motionManager = CMMotionManager()
        motionManager?.startAccelerometerUpdates()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)
        
        if let touchedNode = self.atPoint(touchLocation) as? SKLabelNode, touchedNode.name == "restart" {
            resetScoreAndLevel()
            loadLevel(fileName: "level1")
        }
        
        if let touchedNode = self.atPoint(touchLocation) as? SKLabelNode, touchedNode.name == "outside" {
            isInsideMode = false
            changeMode()
        }
        
        if let touchedNode = self.atPoint(touchLocation) as? SKLabelNode, touchedNode.name == "inside" {
            isInsideMode = true
            changeMode()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard isGameOver == false else { return }
        
        if let accelerometerData = motionManager?.accelerometerData {
            physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.y * -8, dy: accelerometerData.acceleration.x * 8)
        }
    }
    
    func changeMode() {
        if let background = self.childNode(withName: "background") as? SKSpriteNode {
            background.removeFromParent()
        }
        
        self.enumerateChildNodes(withName: "wall") { (node, stop) in
            node.removeFromParent()
        }
        
        resetScoreAndLevel()
        removeLabels()
        createLabels()
        loadBackground(imageName: isInsideMode ? "purple-carpet" : "grass")
        loadLevel(fileName: "level1")
    }
    
    func loadLevel(fileName: String) {
        guard let levelURL = Bundle.main.url(forResource: fileName, withExtension: "txt") else {
            fatalError("Could not find level\(level).txt in the app bundle.")
        }
        
        guard let levelString = try? String(contentsOf: levelURL) else {
            fatalError("Could not load level1.txt from the app bundle.")
        }
        
        clearBoard()
        
        let lines = levelString.components(separatedBy: "\n")
        
        for (row, line) in lines.reversed().enumerated() {
            for (column, letter) in line.enumerated() {
                let position = CGPoint(x: (64 * column) + 32, y: (64 * row) + 32)
                
                if letter == "x" {
                    loadWall(position, imageName: isInsideMode ? "tan-wall" : "fence")
                } else if letter == "v" {
                    loadVortex(position, imageName: isInsideMode ? "dog" : "water")
                } else if letter == "s" {
                    loadStar(position, imageName: "star")
                } else if letter == "f" {
                    loadFinishPoint(position, imageName: "mouse-toy")
                } else if letter == " " {
                    // this is an empty space -- do nothing
                } else {
                    fatalError("Unknown level letter: \(letter)")
                }
            }
        }
        
        loadPlayer(imageName: "cat-marble")
    }
    
    func clearBoard() {
        for child in self.children where child.physicsBody != nil {
            child.removeFromParent()
        }
        
        physicsWorld.gravity = .zero
        isGameOver = false
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }
        
        if nodeA == player {
            playerCollided(with: nodeB)
        } else if nodeB == player {
            playerCollided(with: nodeA)
        }
    }
    
    func playerCollided(with node: SKNode) {
        if node.name == "vortex" {
            isInsideMode ? playSound("bark") : playSound("splash")
            player.physicsBody?.isDynamic = false
            isGameOver = true
            score -= 1
            
            let move = SKAction.move(to: node.position, duration: 0.25)
            let scale = SKAction.scale(to: 0.0001, duration: 0.25)
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([move, scale, remove])
            
            player.run(sequence) { [weak self] in
                self?.loadPlayer(imageName: "cat-marble")
                self?.isGameOver = false
            }
        } else if node.name == "star" {
            playSound("meow")
            node.removeFromParent()
            score += 1
        } else if node.name == "finish" {
            playSound("purr")
            player.physicsBody?.isDynamic = false
            isGameOver = true
            level += 1
            loadLevel(fileName: "level\(level)")
        }
    }
    
    func resetScoreAndLevel() {
        score = 0
        level = 1
    }
    
    func removeLabels() {
        if let node = self.childNode(withName: "levelLabel") as? SKLabelNode {
            node.removeFromParent()
        }
        
        if let node = self.childNode(withName: "scoreLabel") as? SKLabelNode {
            node.removeFromParent()
        }
        
        if let node = self.childNode(withName: "restart") as? SKLabelNode {
            node.removeFromParent()
        }
        
        if let node = self.childNode(withName: "inside") as? SKLabelNode {
            node.removeFromParent()
        }
        
        if let node = self.childNode(withName: "outside") as? SKLabelNode {
            node.removeFromParent()
        }
    }
    
    func createLabels() {
        levelLabel = SKLabelNode(fontNamed: "Georgia")
        levelLabel.name = "levelLabel"
        levelLabel.text = "Level: 1"
        levelLabel.fontColor = isInsideMode ? pink : .white
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 16, y: 16)
        levelLabel.zPosition = 2
        addChild(levelLabel)
        
        scoreLabel = SKLabelNode(fontNamed: "Georgia")
        scoreLabel.name = "scoreLabel"
        scoreLabel.text = "Score: 0"
        scoreLabel.fontColor = isInsideMode ? pink : .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 192, y: 16)
        scoreLabel.zPosition = 2
        addChild(scoreLabel)
        
        restartLabel = SKLabelNode(fontNamed: "Georgia")
        restartLabel.name = "restart"
        restartLabel.text = "Restart"
        restartLabel.fontColor = isInsideMode ? pink : .white
        restartLabel.horizontalAlignmentMode = .left
        restartLabel.position = CGPoint(x: 900, y: 16)
        restartLabel.zPosition = 2
        addChild(restartLabel)
        
        insideLabel = SKLabelNode(fontNamed: "Georgia")
        insideLabel.name = "inside"
        insideLabel.text = "Inside"
        insideLabel.fontColor = isInsideMode ? pink : .white
        insideLabel.horizontalAlignmentMode = .left
        insideLabel.position = CGPoint(x: 16, y: 720)
        insideLabel.zPosition = 2
        addChild(insideLabel)
        
        outsideLabel = SKLabelNode(fontNamed: "Georgia")
        outsideLabel.name = "outside"
        outsideLabel.text = "Outside"
        outsideLabel.fontColor = isInsideMode ? pink : .white
        outsideLabel.horizontalAlignmentMode = .left
        outsideLabel.position = CGPoint(x: 890, y: 720)
        outsideLabel.zPosition = 2
        addChild(outsideLabel)
    }
    
    func loadPlayer(imageName: String) {
        player = SKSpriteNode(imageNamed: imageName)
        player.position = CGPoint(x: 96, y: 672)
        player.zPosition = 1
        
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.linearDamping = 0.5
        
        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        player.physicsBody?.contactTestBitMask = CollisionTypes.star.rawValue | CollisionTypes.vortex.rawValue | CollisionTypes.finish.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.wall.rawValue
        
        addChild(player)
    }
    
    func loadBackground(imageName: String) {
        let background = SKSpriteNode(imageNamed: imageName)
        background.name = "background"
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
    }
    
    func loadWall(_ position: CGPoint, imageName: String) {
        let node = SKSpriteNode(imageNamed: imageName)
        node.name = "wall"
        node.position = position
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.categoryBitMask = CollisionTypes.wall.rawValue
        node.physicsBody?.isDynamic = false
        addChild(node)
    }
    
    func loadVortex(_ position: CGPoint, imageName: String) {
        let node = SKSpriteNode(imageNamed: imageName)
        node.name = "vortex"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.categoryBitMask = CollisionTypes.vortex.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.isDynamic = false
        node.position = position
        addChild(node)
    }
    
    func loadStar(_ position: CGPoint, imageName: String) {
        let node = SKSpriteNode(imageNamed: imageName)
        node.name = "star"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.star.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
        node.physicsBody?.collisionBitMask = 0
        node.position = position
        addChild(node)
    }
    
    func loadFinishPoint(_ position: CGPoint, imageName: String) {
        let node = SKSpriteNode(imageNamed: imageName)
        node.name = "finish"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.finish.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
        node.physicsBody?.collisionBitMask = 0
        node.position = position
        addChild(node)
    }
    
    func playSound(_ soundFile: String) {
        guard let path = Bundle.main.url(forResource: soundFile, withExtension: "wav") else { return }
        do {
          audioPlayer = try AVAudioPlayer(contentsOf: path)
          guard let audioPlayer = audioPlayer else { return }
          audioPlayer.prepareToPlay()
          audioPlayer.play()
        } catch let error as NSError {
          print("error: \(error.localizedDescription)")
        }
  }
}
