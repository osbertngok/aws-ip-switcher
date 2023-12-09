//
//  backend.swift
//  AWS IP Switcher
//
//  Created by Osbert Nephide Ngok on 9/12/2023.
//

import Foundation

import ClientRuntime
@_spi(FileBasedConfig) import AWSClientRuntime

import AwsCommonRuntimeKit

import AWSEC2

import SwiftUI

class Backend: ObservableObject {
    static let shared = Backend()
    
    static func single() -> Backend {
        Task {
            await shared.initializeAsync()
        }
        return .shared
    }
    public func initializeAsync() async -> Void {
        // singleton
        if client == nil {
            SetStatus(status: "Initializing")
            do{
                let configFilePath = Bundle.main.url(forResource: "credentials" , withExtension: "txt")?.path ?? ""
                if configFilePath == "" {
                    SetStatus(status: "Cannot find credentials.txt")
                    return
                }
                let fileBasedConfig = try AwsCommonRuntimeKit.FileBasedConfiguration(configFilePath: configFilePath)
                let resolvedCredentialsProvider = try DefaultChainCredentialsProvider(fileBasedConfig: fileBasedConfig)
                let configuration = try await EC2Client.EC2ClientConfiguration(credentialsProvider: resolvedCredentialsProvider, region: "ap-northeast-1")
                client = EC2Client(config: configuration)
                if client == nil {
                    SetStatus(status: "Client Initialization Failed!")
                    return
                }
                SetStatus(status: "Client is initialized")
                await updateInstanceInfoAsync()
            } catch {
                // do nothing!
               SetStatus(status: "Initialization Failed with Error: \(error)")
            }
        }
        return
    }
    
    public func updateInstanceInfoAsync() async -> Void {
        if client == nil {
            SetStatus(status: "Expecting client is not nil!")
        }
        do{
            SetStatus(status: "Fetching instances...")
            do {
                let result = try await client?.describeInstances(input: DescribeInstancesInput(maxResults:10))
                if result == nil || result!.reservations == nil || result!.reservations!.isEmpty {
                    SetStatus(status: "No instance found!")
                } else {
                    let instanceID = result!.reservations!.first!.instances?.first?.instanceId ?? "N/A"
                    let publicAddress = result!.reservations!.first!.instances?.first?.publicIpAddress ?? "N/A"
                    SetStatus(status: "Instance Info Retrieved.")
                    SetInstanceID(instanceID: instanceID)
                    SetPublicAddress(publicAddress: publicAddress)
                }
            } catch let error as AwsCommonRuntimeKit.CRTError {
                switch error.code {
                case 6153:
                    SetStatus(status: "Incorrect credentials!")
                    break
                default:
                    SetStatus(status: "Fetching Instances with Unknown CRTError: \(error)")
                }
            } catch {
                SetStatus(status: "Fetching Instances with Unknown Error: \(error)")
            }
        } catch {
            // do nothing!
           SetStatus(status: "updateInstanceInfoAsync Failed with Error: \(error)")
        }
    }
    
    public var client: EC2Client? = nil
    @Published var status: String = "Not Initialized"
    @Published var instanceID: String = "N/A"
    @Published var publicAddress: String = "N/A"
    
    public func SetStatus(status: String) -> Void {
        // This is a UI change, so need to make sure it is done in main thread
        DispatchQueue.main.async {
            self.status = status
        }
    }
    
    public func SetInstanceID(instanceID: String) -> Void {
        DispatchQueue.main.async {
            self.instanceID = instanceID
        }
    }
    
    public func SetPublicAddress(publicAddress: String) -> Void {
        DispatchQueue.main.async {
            self.publicAddress = publicAddress
            UIPasteboard.general.string = self.publicAddress
        }
    }
    
    public func changeIPAsync() async -> Void {
        var stage = ""
        do {
            await initializeAsync()
            if publicAddress == "N/A" {
                SetStatus(status: "Cannot Change IP when original IP does not exist!")
                return
            }
            
            if client == nil {
                SetStatus(status: "Cannot Change IP when client is not initialized!")
                return
            }
            // TODO: need to support rollback if things don't go well
            stage = "Getting Original Allocation"
            var allocation = try await client?.describeAddresses(input: DescribeAddressesInput(publicIps:[publicAddress]))
            stage = "Disassociation"
            var result1 = try await client?.disassociateAddress(input: DisassociateAddressInput(publicIp:publicAddress))
            stage = "Release"
            var result2 = try await client?.releaseAddress(input: ReleaseAddressInput(allocationId: allocation?.addresses?[0].allocationId))
            stage = "Allocation"
            var allocationResult = try await client?.allocateAddress(input: AllocateAddressInput(address:nil, dryRun: false))
            stage = "Association"
            var result4 = try await client?.associateAddress(input: AssociateAddressInput(instanceId:instanceID, publicIp:allocationResult?.publicIp))
            await updateInstanceInfoAsync()
        } catch {
            SetStatus(status: "Error in ChangeIPAsync in stage \(stage): \(error)")
        }
        
    }
    
    
    public init() {
        
    }
}
