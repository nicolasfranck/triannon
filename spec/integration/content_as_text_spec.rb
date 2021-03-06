require 'spec_helper'

describe "integration tests for content as text", :vcr do

  before(:all) do
    @root_container = 'context_as_text_intgrtn_specs'
    vcr_cassette_name = "integration_tests_for_content_as_text/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
  end
  after(:all) do
    ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
    vcr_cassette_name = "integration_tests_for_content_as_text/after_spec"
    delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
  end

  it 'body is blank node with content as text' do
    body_text = "I love this!"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         content:chars \"#{body_text}\"
       ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .")
    g = write_anno.graph
    expect(g.size).to eql 7
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(g.query([body_node, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql 7
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(h.query([body_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(h.query([body_node, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text)]).size).to eql 1
  end

  it 'body is blank node with content as text w diff triples' do
    body_text = "I love this!"
    body_format = "text/plain"
    body_lang = "en"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dc11: <http://purl.org/dc/elements/1.1/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         dc11:format \"#{body_format}\";
         dc11:language \"#{body_lang}\";
         content:chars \"#{body_text}\"
       ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .")
    g = write_anno.graph
    expect(g.size).to eql 9
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(g.query([body_node, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node, RDF::DC11.format, RDF::Literal.new(body_format)]).size).to eql 1
    expect(g.query([body_node, RDF::DC11.language, RDF::Literal.new(body_lang)]).size).to eql 1
    expect(g.query([body_node, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql 9
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(h.query([body_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(h.query([body_node, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node, RDF::DC11.format, RDF::Literal.new(body_format)]).size).to eql 1
    expect(h.query([body_node, RDF::DC11.language, RDF::Literal.new(body_lang)]).size).to eql 1
    expect(h.query([body_node, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text)]).size).to eql 1
  end

  it 'two bodies each as blank nodes' do
    body_text1 = "I love this!"
    body_text2 = "I hate this!"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         content:chars \"#{body_text1}\"
       ],
       [
          a content:ContentAsText,
            dcmitype:Text;
          content:chars \"#{body_text2}\"
        ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .")
    g = write_anno.graph
    expect(g.size).to eql 11
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 2
    body_node1 = body_solns.first.object
    expect(g.query([body_node1, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(g.query([body_node1, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node1, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text1)]).size).to eql 1
    body_node2 = body_solns.to_a[1].object
    expect(g.query([body_node2, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(g.query([body_node2, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node2, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text2)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql 11
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 2
    body_node1 = body_solns.first.object
    expect(h.query([body_node1, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(h.query([body_node1, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node1, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text1)]).size).to eql 1
    body_node2 = body_solns.to_a[1].object
    expect(h.query([body_node2, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(h.query([body_node2, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node2, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text2)]).size).to eql 1
  end

end
