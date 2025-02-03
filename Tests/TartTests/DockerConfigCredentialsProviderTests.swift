//
//  Test.swift
//  Tart
//
//  Created by Holloh, Niklas on 03.02.25.
//

import Foundation
import Testing
@testable import tart

struct DockerConfigCredentialsProviderTests {

  // MARK: - Static & Test data
  // credential `hello:world`
  private static let exampleComDockerConfigJsonString = "{\"auths\": {\"example.com\": {\"auth\": \"aGVsbG86d29ybGQ=\"}}}"
  // credential `pepperoni:pizza
  private static let exampleComAlternateDockerConfigJsonString = "{\"auths\": {\"example.com\": {\"auth\": \"cGVwcGVyb25pOnBpenph\"}}}"
  // credential `pepperoni:pizza`
  private static let coffeeComDockerConfigJsonString = "{\"auths\": {\"coffee.com\": {\"auth\": \"cGVwcGVyb25pOnBpenph\"}}}"
  
  private class ProcessInfoMock: ProcessInformation {
    var environment: [String : String]
    
    init(environment: [String : String] = [:]) {
      self.environment = environment
    }
    
    static let noConfig = ProcessInfoMock()
    static let invalidConfig = ProcessInfoMock(environment: ["TART_DOCKER_AUTH_CONFIG": "invalid-json"])
    static let exampleComConfig = ProcessInfoMock(environment: ["TART_DOCKER_AUTH_CONFIG": exampleComDockerConfigJsonString])
    static let exampleComAlternateConfig = ProcessInfoMock(environment: ["TART_DOCKER_AUTH_CONFIG": exampleComDockerConfigJsonString])
    static let coffeeComConfig = ProcessInfoMock(environment: ["TART_DOCKER_AUTH_CONFIG": coffeeComDockerConfigJsonString])
  }
  
  private class FileManagerMock: FileManaging {    
    var fileExistsHandler: ((String) -> Bool)?
    func fileExists(atPath path: String) -> Bool {
      return fileExistsHandler!(path)
    }
    
    var dataHandler: ((URL, Data.ReadingOptions) throws -> Data)?
    func data(contentsOf url: URL, options: Data.ReadingOptions) throws -> Data {
      guard let dataHandler else {
        throw MockError.mockNotConfigured
      }
      return try dataHandler(url, options)
    }
    
    func configPresent(_ isPresent: Bool = true) -> Self {
      fileExistsHandler = { _ in isPresent }
      return self
    }
    
    func configContent(_ content: String) -> Self {
      dataHandler = { _, _ in Data(content.utf8) }
      return self
    }
  }
  
  // MARK: - Tests
  
  @Test func testNilIfNotConfigured() async throws {
    // given
    let processInfo = ProcessInfoMock.noConfig
    let fileManager = FileManagerMock()
      .configPresent(false)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "example.com")
    
    // then
    #expect(resultOptional == nil)
  }
  
  @Test func testFileSystemConfigIfEnvironmentEmpty() async throws {
    // given
    let processInfo = ProcessInfoMock.noConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent(Self.coffeeComDockerConfigJsonString)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "coffee.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "pepperoni")
    #expect(result.1 == "pizza")
  }
  
  @Test func testEnvironmentConfigIfFileSystemNil() async throws {
    // given
    let processInfo = ProcessInfoMock.exampleComConfig
    let fileManager = FileManagerMock()
      .configPresent(false)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "example.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "hello")
    #expect(result.1 == "world")
  }
  
  @Test func testFileSystemConfigIfEnvironmentInvalid() async throws {
    // given
    let processInfo = ProcessInfoMock.invalidConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent(Self.coffeeComDockerConfigJsonString)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "coffee.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "pepperoni")
    #expect(result.1 == "pizza")
  }
  
  @Test func testEnvironmentConfigIfFileSystemInvalid() async throws {
    // given
    let processInfo = ProcessInfoMock.exampleComConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent("invalid-json")
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "example.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "hello")
    #expect(result.1 == "world")
  }
  
  @Test func testNilIfAllConfigurationsInvalid() async throws {
    // given
    let processInfo = ProcessInfoMock.invalidConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent("invalid-json")
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "coffee.com")
    
    // then
    #expect(resultOptional == nil)
  }
  
  @Test func testLookupInBothSources() async throws {
    // given
    let processInfo = ProcessInfoMock.exampleComConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent(Self.coffeeComDockerConfigJsonString)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "coffee.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "pepperoni")
    #expect(result.1 == "pizza")
  }
  
  @Test func testEnvironmentPrecedenceIfDuplicateHost() async throws {
    // given
    let processInfo = ProcessInfoMock.exampleComConfig
    let fileManager = FileManagerMock()
      .configPresent()
      .configContent(Self.exampleComAlternateDockerConfigJsonString)
    let provider = DockerConfigCredentialsProvider(fileManager: fileManager, processInfo: processInfo)
    
    // when
    let resultOptional = try provider.retrieve(host: "example.com")
    
    // then
    let result = try #require(resultOptional)
    #expect(result.0 == "hello")
    #expect(result.1 == "world")
  }

}
