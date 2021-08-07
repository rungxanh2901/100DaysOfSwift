//
//  SelfieShareVC.swift
//  SelfieShare
//
//  Created by Joe Pham on 2021-08-06.
//

import UIKit
import MultipeerConnectivity

class SelfieShareVC: UIViewController {
	
	// MARK: Properties
	
	// For UI
	private var collectionView			: UICollectionView!
	private var images					= [UIImage]()
	
	// For broadcasting
	var peerID						: MCPeerID?
	var mcSession						: MCSession?
	var mcAdAssistant					: MCAdvertiserAssistant?
	
	// MARK: Life Cycle
	override func viewDidLoad() {
		super.viewDidLoad()
		configureViewController()
		configureCollectionView()
		configureMultipeerConnection()
	}
}


// MARK: Data Source

extension SelfieShareVC: UICollectionViewDataSource {
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelfieCell.reuseID, for: indexPath)
		if let imageView = cell.viewWithTag(1000) as? UIImageView { imageView.image = images[indexPath.item] }
		return cell
	}
	
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return images.count
	}
}


extension SelfieShareVC: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	@objc
	final func importPicture() {
		let picker				= UIImagePickerController()
		picker.allowsEditing	= true
		picker.delegate			= self
		present(picker, animated: true)
	}
	
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		guard let image = info[.editedImage] as? UIImage else { return }
		dismiss(animated: true)
		
		updateSourceData(with: image)
		broadcast(with: image)
	}

	
	// MARK: Broadcasting-end Method
	func broadcast(with image: UIImage) {
		guard let mcSession = mcSession else { return }
		if mcSession.connectedPeers.isEmpty == false {
			if let imageData = image.pngData() {
				do { try mcSession.send(imageData, toPeers: mcSession.connectedPeers, with: .reliable) }
				catch { presentAlertOnMainThread(title: "Send Error", message: error.localizedDescription, buttonTitle: "Ok") }
			}
		}
	}
	
	
	// MARK: Display Broadcasting Result
	func updateSourceData(with image: UIImage) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			self.images.insert(image, at: 0)
			self.collectionView.reloadData()
		}
	}
}


// MARK: Broadcasting
extension SelfieShareVC: MCSessionDelegate {
	
	final func configureMultipeerConnection() {
		peerID				= MCPeerID(displayName: UIDevice.current.name)
		mcSession			= MCSession(peer: peerID!, securityIdentity: nil, encryptionPreference: .required)
		mcSession?.delegate	= self
	}
	
	
	@objc
	final func showConnectionPrompt() {
		let ac = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
		ac.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
		ac.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
		ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		present(ac, animated: true)
	}
	
	
	final func startHosting(_ action: UIAlertAction) {
		guard let mcSession = mcSession else { return }
		mcAdAssistant		= MCAdvertiserAssistant(serviceType: MCConnectivity.serviceID, discoveryInfo: nil, session: mcSession)
		mcAdAssistant?.start()
	}
	
	
	final func joinSession(_ action: UIAlertAction) {
		guard let mcSession = mcSession else { return }
		let mcBrowser		= MCBrowserViewController(serviceType: MCConnectivity.serviceID, session: mcSession)
		mcBrowser.delegate	= self
		present(mcBrowser, animated: true)
	}
}


// MARK: Browser Delegate Methods
extension SelfieShareVC: MCBrowserViewControllerDelegate {
	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
	
	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
	
	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {	}
	
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}
	
	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}
	
	// MARK: Receiving-end Method
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		// receiving end of the broadcast session
		if let image = UIImage(data: data) { updateSourceData(with: image) }
	}
	
	
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		// for debugging
		switch state {
		case .connected:	print("Connected: \(peerID.displayName)")
		case .connecting:	print("Connecting: \(peerID.displayName)")
		case .notConnected:	print("Not Connected: \(peerID.displayName)")
		@unknown default:	print("Unknown State Received: \(peerID.displayName)")
		}
	}
}


// MARK: UI Config

extension SelfieShareVC: UICollectionViewDelegate {
	
	final func configureViewController() {
		view.backgroundColor	= .systemBackground
		title					= Bundle.main.displayName
		
		let connectButton		= UIBarButtonItem(image: Images.connection, style: .plain, target: self, action: #selector(showConnectionPrompt))
		let cameraButton		= UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
		let spacer				= UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		
		setToolbarItems([connectButton, spacer, cameraButton], animated: true)
		navigationController?.isToolbarHidden = false
	}
	
	
	final func configureCollectionView() {
		let flowLayout					= UICollectionViewFlowLayout()
		flowLayout.configureTwoColumnFlowLayout(in: view)
		
		collectionView					= UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
		collectionView.backgroundColor 	= .systemBackground
		collectionView.dataSource		= self
		collectionView.delegate			= self
		collectionView.register(SelfieCell.self, forCellWithReuseIdentifier: SelfieCell.reuseID)
		view.addSubview(collectionView)
	}
}
