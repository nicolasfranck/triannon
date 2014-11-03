require 'spec_helper'

describe Triannon::LdpToOaMapper do
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:body_stmts) { RDF::Graph.new.from_ttl(body_ttl).statements }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe ".ldp_to_oa" do
    it "maps an AnnotationLdp to an OA RDF::Graph" do
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa ldp_anno

      resp = oa_graph.query [nil, RDF.type, RDF::OpenAnnotation.Annotation ]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end
    it "calls #extract_base" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_base)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
    it "calls #extract_bodies" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_bodies)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
    it "calls #extract_targets" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_targets)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
  end

  describe "#extract_base" do
    let(:mapper) { Triannon::LdpToOaMapper.new ldp_anno  }

    it "extracts the id from the root subject" do
      mapper.extract_base
      expect(mapper.id).to eq 'deb27887-1241-4ccc-a09c-439293d73fbb'
    end

    it "builds the base identifier from the Config.open_annotation.base_uri and @id" do
      mapper.extract_base
      resp = mapper.oa_graph.query [nil,RDF.type, RDF::OpenAnnotation.Annotation ]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end

    it "checks the RDF.type to be RDF::OpenAnnotation.Annotation" do
      skip "raise an exception if it is not?"
    end

    it "extracts the motivations" do
      mapper.extract_base

      res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.motivatedBy, nil]
      expect(res.count).to eq 1
      expect(res.first.object).to eq RDF::OpenAnnotation.commenting
    end
  end

  describe "#extract_bodies" do
    it "calls #map_external_ref when the body is an external ref" do
      body_ttl = "
        <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> 
        <http://triannon.stanford.edu/ns/externalReference> <http://some.external.ref> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_bodies
    end
    it "calls #map_content_as_text when the content is text" do
      ldp_anno.load_statements_into_graph body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_content_as_text)
      mapper.extract_bodies
    end
    it "calls #map_specific_resource when body is SpecificResource" do
      body_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_bodies
    end
  end

  describe "#extract_targets" do
    it "calls #map_external_ref when the body is an external ref" do
      ldp_anno.load_statements_into_graph target_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_targets
    end
    it "calls #map_specific_resource when body is SpecificResource" do
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_targets
    end
  end
  
  describe '#map_external_ref' do
    let(:target_url) { "http://purl.stanford.edu/kq131cs7229" }
    it "adds statement with external uri from externalReference statement to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 1
      uri = solns.first.object
      expect(uri.class).to eq RDF::URI
      expect(uri.to_s).to eql target_url
      expect(mapper.oa_graph.size).to eql (orig_size + 1)
    end
    it "returns true if it adds statements to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_external_ref(body_uri, RDF::OpenAnnotation.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if there is no Triannon:externalReference in the container" do
      # see 'returns false if it doesn't change oa_graph'
    end
    it "only maps the first Triannon:externalReference if there is more than one in the container" do
      # there should only ever be one Triannon:externalReference in the object LDP container
      target_url1 = target_url
      target_url2 = "http://purl.stanford.edu/ab123cd4567"
      target_ttl = "
        <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> 
        <http://triannon.stanford.edu/ns/externalReference> <#{target_url1}>, <#{target_url2}>; ."
      my_target_stmts = RDF::Graph.new.from_ttl(target_ttl).statements
      ldp_anno.load_statements_into_graph my_target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper.oa_graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).size).to eq 0
      
      mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)
      expect(mapper.oa_graph.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI.new(target_url1)]).size).to eq 1
      expect(mapper.oa_graph.query([nil, nil, RDF::URI.new(target_url2)]).size).to eq 0
    end
    it "includes SemanticTags when present" do
      body_ext_url = "http://some.external.ref"
      stored_body_obj_url = "#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
      body_ttl = "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      <#{stored_body_obj_url}> a openannotation:SemanticTag;
         triannon:externalReference <#{body_ext_url}> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::OpenAnnotation.hasBody)
      
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 1
      uri_obj = solns.first.object
      expect(uri_obj).to eql RDF::URI.new(body_ext_url)
      expect(mapper.oa_graph.query([uri_obj, RDF.type, RDF::OpenAnnotation.SemanticTag]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 2
    end
    it "includes additional metadata when present" do
      body_ext_url = "http://some.external.ref"
      body_format = "audio/mpeg3"
      stored_body_obj_url = "#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
      body_ttl = "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      <#{stored_body_obj_url}> a dcmitype:Sound;
         triannon:externalReference <#{body_ext_url}>;
         dc11:format \"#{body_format}\" ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::OpenAnnotation.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 1
      uri_obj = solns.first.object
      expect(uri_obj).to eql RDF::URI.new(body_ext_url)
      expect(mapper.oa_graph.query([uri_obj, RDF.type, RDF::DCMIType.Sound]).size).to eql 1
      expect(mapper.oa_graph.query([uri_obj, RDF::DC11.format, body_format]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 3
    end
  end # #map_external_ref

  describe '#map_content_as_text' do
    it "adds de-skolemized blank node with type ContentAsText to @oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 0
      
      mapper.map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody)
      
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      expect(blank_node.class).to eq RDF::Node
      expect(mapper.oa_graph.query([blank_node, RDF.type, RDF::Content.ContentAsText]).size).to eq 1
    end
    it "adds all relevant statements in simple skolemized blank node to @oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Content.ContentAsText]
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::DCMIType.Text]
      expect(blank_node_solns).to include [blank_node, RDF::Content.chars, "I love this!"]
    end
    it "adds all relevant statements in skolemized blank node to @oa_graph" do
      body_container_stmts = RDF::Turtle::Reader.new('
      @prefix content: <http://www.w3.org/2011/content#> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           dcmitype:Text,
           content:ContentAsText;
         dc11:format "text/plain";
         dc11:language "en";
         content:chars "I love this!";
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> .
      ').statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 5
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Content.ContentAsText]
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::DCMIType.Text]
      expect(blank_node_solns).to include [blank_node, RDF::DC11.format, "text/plain"]
      expect(blank_node_solns).to include [blank_node, RDF::DC11.language, "en"]
      expect(blank_node_solns).to include [blank_node, RDF::Content.chars, "I love this!"]
    end
    it "returns true if it adds statements to oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_content_as_text(target_uri, RDF::OpenAnnotation.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have ContentAsText type" do
      # see 'returns false if it doesn't change oa_graph'
    end
  end # #map_content_as_text

  describe '#map_specific_resource' do
    it "simple source" do
      # see text position selector test
    end
    it "source with add'l properties" do
      # see fragment selector test
    end
    it "TextPositionSelector" do
      stored_target_obj_url = "#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .
      
      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .
         
      <#{stored_selector_obj_url}> a openannotation:TextPositionSelector;
         openannotation:start \"0\"^^xsd:long;
         openannotation:end \"66\"^^xsd:long .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::OpenAnnotation.SpecificResource]
      # source obj is written as a hashURI by LdpCreator
      source_obj = RDF::URI.new(stored_source_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSource, source_obj]
      selector_obj = RDF::URI.new(stored_selector_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSelector, selector_obj]
      
      # source obj hashURI is in the same response due to fcrepo4 implementation of hash URI nodes
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 1
      expect(source_obj_subject_solns).to include [source_obj, RDF::Triannon.externalReference, RDF::URI.new(source_url)]

      # selector obj blank node is in the same fedora response due to fcrepo4 implementation
      selector_obj_subject_solns = mapper.oa_graph.query [selector_obj, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 3
      expect(selector_obj_subject_solns).to include [selector_obj, RDF.type, RDF::OpenAnnotation.TextPositionSelector]
      start_obj_solns = mapper.oa_graph.query [selector_obj, RDF::OpenAnnotation.start, nil]
      expect(start_obj_solns.count).to eq 1
      start_obj = start_obj_solns.first.object
      expect(start_obj.to_s).to eql "0"
# FIXME:  these should be converted back to nonNegativeInteger, per OA spec  
# See https://github.com/sul-dlss/triannon/issues/78  
      expect(start_obj.datatype).to eql RDF::XSD.long
      end_obj_solns = mapper.oa_graph.query [selector_obj, RDF::OpenAnnotation.end, nil]
      expect(end_obj_solns.count).to eq 1
      end_obj = end_obj_solns.first.object
      expect(end_obj.to_s).to eql "66"
      expect(end_obj.datatype).to eql RDF::XSD.long
    end
    it "TextQuoteSelector" do
      stored_target_obj_url = "#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      suffix = " and The Canonical Epistles,"
      exact = "third and fourth Gospels"
      prefix = "manuscript which comprised the "
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .
      
      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .
         
      <#{stored_selector_obj_url}> a openannotation:TextQuoteSelector;
         openannotation:suffix \"#{suffix}\";
         openannotation:exact \"#{exact}\";
         openannotation:prefix \"#{prefix}\" .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::OpenAnnotation.SpecificResource]
      # source obj is written as a hashURI by LdpCreator
      source_obj = RDF::URI.new(stored_source_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSource, source_obj]
      selector_obj = RDF::URI.new(stored_selector_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSelector, selector_obj]
      
      # source obj hashURI is in the same response due to fcrepo4 implementation of hash URI nodes
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 1
      expect(source_obj_subject_solns).to include [source_obj, RDF::Triannon.externalReference, source_url]

      # selector obj blank node is in the same fedora response due to fcrepo4 implementation
      selector_obj_subject_solns = mapper.oa_graph.query [selector_obj, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 4
      expect(selector_obj_subject_solns).to include [selector_obj, RDF.type, RDF::OpenAnnotation.TextQuoteSelector]
      expect(selector_obj_subject_solns).to include [selector_obj, RDF::OpenAnnotation.suffix, suffix]
      expect(selector_obj_subject_solns).to include [selector_obj, RDF::OpenAnnotation.exact, exact]
      expect(selector_obj_subject_solns).to include [selector_obj, RDF::OpenAnnotation.prefix, prefix]
    end
    it "FragmentSelector" do
      stored_target_obj_url = "#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
      conforms_to_url = "http://www.w3.org/TR/media-frags/"
      frag_value = "xywh=0,0,200,200"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix dcterms: <http://purl.org/dc/terms/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .
      
      <#{stored_source_obj_url}> a dcmitype:Image;
         triannon:externalReference <#{source_url}> .
         
      <#{stored_selector_obj_url}> a openannotation:FragmentSelector;
         rdf:value \"#{frag_value}\";
         dcterms:conformsTo <#{conforms_to_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::OpenAnnotation.SpecificResource]
      # source obj is written as a hashURI by LdpCreator
      source_obj = RDF::URI.new(stored_source_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSource, source_obj]
      selector_obj = RDF::URI.new(stored_selector_obj_url)
      expect(blank_node_solns).to include [blank_node, RDF::OpenAnnotation.hasSelector, selector_obj]
      
      # source obj hashURI is in the same response due to fcrepo4 implementation of hash URI nodes
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 2
      expect(source_obj_subject_solns).to include [source_obj, RDF.type, RDF::DCMIType.Image]
      expect(source_obj_subject_solns).to include [source_obj, RDF::Triannon.externalReference, source_url]
      
      # selector obj blank node is in the same fedora response due to fcrepo4 implementation
      selector_obj_subject_solns = mapper.oa_graph.query [selector_obj, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 3
      expect(selector_obj_subject_solns).to include [selector_obj, RDF.type, RDF::OpenAnnotation.FragmentSelector]
      expect(selector_obj_subject_solns).to include [selector_obj, RDF.value, frag_value]
      expect(selector_obj_subject_solns).to include [selector_obj, RDF::DC.conformsTo, conforms_to_url]
    end
    it "DataPositionSelector" do
      skip 'DataPositionSelector not yet implemented'
    end
    it "SvgSelector" do
      skip 'SvgSelector not yet implemented'
    end
    it "returns true if it adds statements to oa_graph" do
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      
      <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{Triannon.config[:ldp_url]}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first
      
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      
      expect(mapper.map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have type SpecificResource" do
      # see 'returns false if it doesn't change oa_graph'
    end
  end
  
end
