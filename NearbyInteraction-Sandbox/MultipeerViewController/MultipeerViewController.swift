//
//  MultipeerViewController.swift
//  NearbyInteraction-Sandbox
//
//  Created by Eduard on 16.06.2022.
//

import MultipeerConnectivity
import NearbyInteraction
import UIKit

final class MultipeerViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet private var statusLabel: UILabel!
    @IBOutlet private var distanceLabel: UILabel!
    @IBOutlet private var sendButton: UIButton!
    @IBOutlet private var cancelButton: UIButton!
    @IBOutlet private var segmentedControl: UISegmentedControl!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSegmentedControl()
        peerID = MCPeerID(displayName: deviceName)
        multipeerSession = MCSession(peer: getPeerID(), securityIdentity: nil, encryptionPreference: .none)
        multipeerSession?.delegate = self
        startBrowser()
    }

    // MARK: - Actions
    @IBAction func didTapSendButton(_ sender: Any) {
        sharedTokenWithPeer = false
        stopBrowsingAndAdvertising()
        isSender = true
        startAdvertiser()
    }

    @IBAction func didTapCancelButton(_ sender: Any) {
        if let connectedPeer = multipeerSession?.connectedPeers.first {
            multipeerSession?.cancelConnectPeer(connectedPeer)
            multipeerSession?.disconnect()
        }
        if nearbySession != nil {
            nearbySession?.invalidate()
            nearbySession = nil
        }
        stopBrowsingAndAdvertising()
        startBrowser()
        isSender = false
    }
    
    
    // MARK: - Private constants
    let serviceType = "nisandbox"
    let nearbyTresholdDistance: Float = 0.15

    // MARK: - Private
    var nearbySession: NISession?
    var multipeerSession: MCSession?
    var peerID: MCPeerID?
    var browser: MCNearbyServiceBrowser?
    var advertiser: MCNearbyServiceAdvertiser?
    let deviceName = UIDevice.current.name
    var peers: [MCPeerID] = []
    var connectedPeer: MCPeerID?
    var sharedTokenWithPeer = false
    var peerDisplayName: String?
    var isSender = false
}

// MARK: - Private methods
private extension MultipeerViewController {
    func startAdvertiser() {
        advertiser = MCNearbyServiceAdvertiser(peer: getPeerID(), discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        style(for: .advertising)
    }

    func startBrowser() {
        browser = MCNearbyServiceBrowser(peer: getPeerID(), serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        style(for: .browsing)
    }

    func stopBrowsingAndAdvertising() {
        if let unwrappedBrowser = browser {
            unwrappedBrowser.stopBrowsingForPeers()
        }
        if let unwrappedAdvertiser = advertiser {
            unwrappedAdvertiser.stopAdvertisingPeer()
        }
        multipeerSession?.disconnect()
    }

    func addPeer(name: String) {
        for peer in peers {
            if peer.displayName == name {
                return
            }
        }
        let newPeer = MCPeerID.init(displayName: name)
        peers.append(newPeer)
    }

    func getPeerID() -> MCPeerID {
        if let peerId = self.peerID {
            return peerId
        } else {
            let peerId = MCPeerID(displayName: deviceName)
            self.peerID = peerId
            return peerId
        }
    }

    func send(_ discoveryToken: NIDiscoveryToken) {
        guard let connectedPeersCount = multipeerSession?.connectedPeers.count,
              let connectedPeers = multipeerSession?.connectedPeers,
              let messageData = try? NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true),
              connectedPeersCount > 0 else {
            return
        }
        do {
            try self.multipeerSession?.send(messageData, toPeers: connectedPeers, with: .reliable)
        } catch { }
    }

    func send(message: SandboxDTO) {
        guard let connectedPeersCount = multipeerSession?.connectedPeers.count,
              let connectedPeers = multipeerSession?.connectedPeers,
              let messageData = try? JSONEncoder().encode(message),
              connectedPeersCount > 0 else {
            return
        }
        do {
            try self.multipeerSession?.send(messageData, toPeers: connectedPeers, with: .reliable)
        } catch { }
    }

    func peerDidShareDiscoveryToken(peer: MCPeerID, token: NIDiscoveryToken) {
        if isSender {
            let config = NINearbyPeerConfiguration(peerToken: token)
            guard nearbySession != nil else { fatalError("Nearby session is nil") }
            nearbySession?.run(config)
        } else {
            let config = NINearbyPeerConfiguration(peerToken: token)
            nearbySession = NISession()
            nearbySession?.delegate = self
            nearbySession?.run(config)
            guard let discoveryToken = nearbySession?.discoveryToken else { fatalError("Discovery token not exist") }
            send(discoveryToken)
        }
    }

    func isNearby(_ distance: Float) -> Bool {
        distance <= nearbyTresholdDistance
    }
}

// MARK: - Style
private extension MultipeerViewController {
    func configureSegmentedControl() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "5", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "4", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "3", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "2", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "1", at: 0, animated: false)
        segmentedControl.selectedSegmentIndex = 0
    }

    func style(for state: MultipeerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .browsing:
                self.distanceLabel.isHidden = true
                self.statusLabel.text = ""
                self.statusLabel.textColor = .black
                self.sendButton.isHidden = false
                self.cancelButton.isHidden = true
                self.segmentedControl.isHidden = false
            case .advertising:
                self.distanceLabel.isHidden = true
                self.statusLabel.text = "Searching for device"
                self.statusLabel.textColor = .black
                self.sendButton.isHidden = true
                self.cancelButton.isHidden = false
                self.segmentedControl.isHidden = true
            case .connecting:
                self.distanceLabel.isHidden = true
                self.statusLabel.text = "Connecting to device"
                self.statusLabel.textColor = .orange
                self.sendButton.isHidden = true
                self.cancelButton.isHidden = false
                self.segmentedControl.isHidden = true
            case .connected:
                self.distanceLabel.isHidden = false
                self.statusLabel.text = "Connected to device. Tap to pass data."
                self.statusLabel.textColor = .green
                self.sendButton.isHidden = true
                self.cancelButton.isHidden = false
                self.segmentedControl.isHidden = true
            }
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        addPeer(name: peerID.displayName)
        switch state {
        case .connected:
            if isSender {
                nearbySession = NISession()
                nearbySession?.delegate = self
                guard let discoveryToken = nearbySession?.discoveryToken else {
                    fatalError("Discovery token not exist")
                }
                if !sharedTokenWithPeer {
                    send(discoveryToken)
                }
            } else {
            }
            style(for: .connected)
        case .connecting:
            style(for: .connecting)
        case .notConnected:
            style(for: .browsing)
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let discoveryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            peerDidShareDiscoveryToken(peer: peerID, token: discoveryToken)
        } else if let dto = try? JSONDecoder().decode(SandboxDTO.self, from: data) {
            switch dto.type {
            case .paymentTransferMessage:
                showAlert(title: dto.description ?? "")
                send(message: SandboxDTO(type: .messageReceivedConfirmation, description: nil))
                nearbySession?.invalidate()
                nearbySession = nil
                stopBrowsingAndAdvertising()
                startBrowser()
            case .messageReceivedConfirmation:
                nearbySession?.invalidate()
                nearbySession = nil
                stopBrowsingAndAdvertising()
                startBrowser()
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerViewController: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, multipeerSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerViewController: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let unwrappedSession = multipeerSession else { return }
        browser.invitePeer(peerID, to: unwrappedSession, withContext: nil, timeout: 10.0)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    }
}


// MARK: - NISessionDelegate
extension MultipeerViewController: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let distance = nearbyObjects.first?.distance else { return }
        distanceLabel.text = String(format:"%.2f m", distance)
        if isNearby(distance), isSender {
            let description = String(segmentedControl.selectedSegmentIndex + 1)
            send(message: SandboxDTO(type: .paymentTransferMessage, description: description))
            isSender = false
        }
    }
}
