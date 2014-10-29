require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Triannon::LdpLoader do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:root_anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_root_anno_container.ttl') }

  describe "#load_annotation" do

    # TODO super brittle since it stubs the whole http interaction
    it "retrives the ttl data for an annotation when given an id" do
      conn = double()
      resp = double()
      allow(resp).to receive(:body).and_return(anno_ttl)
      allow(conn).to receive(:get).and_return(resp)

      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:conn).and_return(conn)

      loader.load_annotation
      expect(loader.annotation.graph.class).to eq(RDF::Graph)
      expect(loader.annotation.graph.count).to be > 1
    end

    it "no triple in the graph should have the body uri as a subject" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl)
      loader.load_annotation
      body_uri = loader.annotation.body_uris.first
      result = loader.annotation.graph.query [body_uri, nil, nil]
      expect(result.size).to eq 0
    end

    it "no triple in the graph should have the target uri as a subject" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl)
      loader.load_annotation
      target_uri = loader.annotation.target_uris.first
      result = loader.annotation.graph.query [target_uri, nil, nil]
      expect(result.size).to eq 0
    end
  end

  describe "#load_body" do
    it "retrieves the body by using the hasBody value from the annotation" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, body_ttl)
      loader.load_annotation
      loader.load_body
      body_uri = loader.annotation.body_uris.first
      result = loader.annotation.graph.query [body_uri, RDF::Content.chars, nil]
      expect(result.first.object.to_s).to match /I love this/
    end
  end

  describe "#load_target" do
    it "retrieves the target by using hasTarget value from the annotation" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, target_ttl)
      loader.load_annotation
      loader.load_target
      target_uri = loader.annotation.target_uris.first
      result = loader.annotation.graph.query [target_uri, RDF::Triannon.externalReference, nil]
      expect(result.first.object.to_s).to match /kq131cs7229/
    end
  end

  describe ".find_all" do
    it "returns an array of Triannon::Annnotation objects, with just id set" do
      loader = Triannon::LdpLoader.new
      allow(loader).to receive(:get_ttl).and_return(root_anno_ttl)
      objs = loader.find_all

      expect(objs.size).to be > 0
      expect(objs.first.class).to eq Triannon::Annotation
      expect(objs.first.id).to_not be_nil
    end

  end

end