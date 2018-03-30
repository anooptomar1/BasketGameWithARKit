//
//  ViewController.swift
//  AR-Hoops
//
//  Created by MacBook  on 09/12/2017.
//  Copyright © 2017 Onurcan Yurt. All rights reserved.
//

import UIKit
import ARKit
import Each
class ViewController: UIViewController, ARSCNViewDelegate {
    
    
    //EKRANA DOKUNARAK BASKET ATMA (BASILI TUTTUKCA SİDDETİNİ ARTTIRIYORUZ)
    
    
    @IBOutlet weak var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    //topun siddeti bazı olaylara gore degiir bu degisimi bu degiskende tutuyoruz
    var power: Float = 1
    
    
    
    //burada timer ekledik timerın gorevi ekrana ne kadar cok dokunursak o kadar top ssiddetleniyordu
    //işte o siddeti sn cinsinden tutup siddetin dereceseni belirliycek
    //(0.05) yani her 0.05 sn de bir artıcak ve tetiklenicek
    //bunu asagıdaki timer.performda isimize yarar .perform ile her 0.05 sn de o metod cagrılcak
    //ve ekrana ne kadaruzun basarsak orada topun güç arttırılacak
    let timer = Each(0.05).seconds
    
    //Burada basketin atılıp atılmadıgını tutuyoruz yani eger atılmıssa true oluyor
    //ve timer baslıyor ve ekranan basılı tutma burakılınca false oluyo ve obje parent node den siliniyor
    var basketAdded: Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        //yuzey algılamasını yatay yaptık
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.delegate = self
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.cancelsTouchesInView = false
        
    }
    
    //bu metodumuz hatırlarsak ekrana basılı tutuncaki islemleri tutuyordu
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.basketAdded == true {
            
            //burada ekrana basili tutulcuktan timer tetikleniyor (0.05 sn de) ve topun siddeti artıyor
            timer.perform(closure: { () -> NextStep in
                self.power = self.power + 1
                return .continue //contunie ile islemin tekrarı saglanır
            })
        }
    }
    
    //ve ekrana dokunma işlemi bırakılınca calısan metod burada da timer durur ve
    //shootbal metodu ile top atılır ve power = 1 yani guc dusurulur
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.basketAdded == true {
            self.timer.stop()
            self.shootBall()
        }
        self.power = 1
    }
    
    //burada topumuzun olusturulma ve atılma olayını inceliyoruz
    func shootBall() {
        
        //en basta cizim uygulamasında kameramızın tam orta noktasını almıstı hatırlarsak
        //pointOFView ve location + orientation ile yine aynı sekil orta konumda topumuzu olusturuyoruz
        guard let pointOfView = self.sceneView.pointOfView else {return}
        
        //ve bundan once olusturdumuz bi metodla daha once atılmıs topları siliyoruz
        self.removeEveryOtherBall()
        let transform = pointOfView.transform
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let position = location + orientation
        
        //topumuza arkaplan ve radius verdik
        let ball = SCNNode(geometry: SCNSphere(radius: 0.25))
        ball.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "ball")
        ball.position = position
        
        //topumuza fizik ozelligi ekliyoruz kuvvetlerden ve yercekiminden etkilensin diye
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = body
        
        //burada kod ile olusturdumuz icin topumuzun adı yoktu o yuzden ad verdik
        //ad vermemizin nedeni asagıda bu topu silerken bu ad ile sileriz
        ball.name = "Basketball"
        
        
        //Burada cok onemli bir ozellik çarpışmalarda kaybettiği veya kazandığı kinetik enerjiyi belirleyen bir faktör olan restution i belirledik
        body.restitution = 0.2
        
        //burada da topumuza uyguladımız kuvveti belirliyoruz hatırlarsak power degiskeni ile ekrana basılı tutma suresine gore topa
        //guc veriyorduk iste o burada gerceklesir
        ball.physicsBody?.applyForce(SCNVector3(orientation.x*power, orientation.y*power, orientation.z*power), asImpulse: true)
        self.sceneView.scene.rootNode.addChildNode(ball)
        
        
    }
    
    //ekrana dokunma olayı (her ekrana dokunuldugunda calısır)
    @objc func handleTap(sender: UITapGestureRecognizer) {
        
        
        //Burada dokunulan yerin bir sceneview mi oldugu kontrol ettik aslında gereksiz cunku zaten butun ekranı kaplıyor
        //zaten burada her turlu ihtimale karsı bi kontrol yapıyoruz guard let ile kontrol
        guard let sceneView = sender.view as? ARSCNView else {return}
        
        //burada hittest ile dokunulan yer bir yatay yuzeymi kontrol ederiz
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingExtent])
        if !hitTestResult.isEmpty {
            
            //ve eger dogruysa asagıdaki addBasketArea metoduyla basket sahası scn dosyamızı eklirz
            self.addBasketArea(hitTestResult: hitTestResult.first!)
        }
    }
    
    func addBasketArea(hitTestResult: ARHitTestResult) {
        if basketAdded == false {
            
            //basketbolsahamızı scn dosyamızı ekliyoruz
            let basketScene = SCNScene(named: "Basketball.scnassets/Basketball.scn")
            let basketNode = basketScene?.rootNode.childNode(withName: "Basket", recursively: false)
            
            //hittest ile secilen alanı aldık  worldTransform ile matris seklinde ve bu matisin 3. yani son sutunundaki x,y,z y, alıyoruz
            let positionOfPlane = hitTestResult.worldTransform.columns.3
            let xPosition = positionOfPlane.x
            let yPosition = positionOfPlane.y
            let zPosition = positionOfPlane.z
            basketNode?.position = SCNVector3(xPosition,yPosition,zPosition)
            
            //burada normalde bu tarz objeleri direk "basketNode?.physicsBody = SCNPhysicsBody.static()"
            //komutuyla fizikbody ekliyoduk ancak bu sekilde pota cemberi, pota cemberinin icinden top gecme vb. gibi
            //ekstra olaylar oldugundan asagıdaki kodu yazdık ve seklimizin en  ince ayrıntılarına kadar fizikBody ekledik
            //bu sayede cemberden top gecer yoksa gecmezdi SCNPhysicsBody.static() seklinde yazsaydık
            
            basketNode?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketNode!, options: [SCNPhysicsShape.Option.keepAsCompound: true, SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
            self.sceneView.scene.rootNode.addChildNode(basketNode!)
            
            //ve sahamız eklendikten 2 sn sonra basket atma ozelligini true ypıyoruz
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.basketAdded = true
            }
        }
    }
    
    
    //bu metod ile eski atılan topları siliyoruz
    func removeEveryOtherBall() {
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "Basketball" {
                node.removeFromParentNode()
            }
        }
    }
    
    deinit {
        print("durr")
        self.timer.stop()
    }
    
}

//burada da hatırlarsak eger toplama islemini baska tur degiskenlerde mesela vector3 lerde yapıcaksak onu tanımlıyorduk ve bu sayede
//artık vector3 birimlerini de + operatoruyle her yerde toplabiliyorduk
func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

