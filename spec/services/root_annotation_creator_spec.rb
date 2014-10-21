require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Triannon::RootAnnotationCreator, :vcr do

  describe "#create" do
    let(:dummy_url) { 'http://localhost:8080/rest/bork' }
    let(:conn) { Faraday.new :url => dummy_url  }

    before(:each) do
       config = { :ldp_url =>  dummy_url }
       allow(Triannon).to receive(:config).and_return(config)
       conn.delete
    end

    after(:each) { conn.delete }

    it "creates the root annotations container if it does not already exist" do
      expect(Triannon::RootAnnotationCreator.create).to eq true

      resp = conn.get do |req|
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.status).to eq 200

      uri = RDF::URI.new Triannon.config[:ldp_url]
      g = RDF::Graph.new
      g.from_ttl resp.body
      q = RDF::Query.new
      q << [uri, RDF.type, RDF::LDP.BasicContainer]
      soln = g.query q
      expect(soln.size).to eq 1
    end

    it "does not do anything if the root annotations container already exists" do
      expect(Triannon::RootAnnotationCreator.create).to eq true
      expect(Triannon::RootAnnotationCreator.create).to eq false

      resp = conn.get
      expect(resp.status).to eq 200
    end
  end
end