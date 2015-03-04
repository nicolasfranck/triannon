require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }
  let(:bookmark_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json"), id: '123'}
  let(:body_chars_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl"), id: '666' }

  # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
  json_regex = /\A\{.+\}\Z/m

  it "should have an index" do
    a1 = Triannon::Annotation.new :id => 'abc'
    a2 = Triannon::Annotation.new :id => 'dce'
    allow(Triannon::Annotation).to receive(:all).and_return [a1, a2]
    get :index
  end

  context "#create" do
    let (:ttl_data) {Triannon.annotation_fixture("body-chars.ttl")}
    it 'creates a new annotation from the body of the request' do
      post :create, ttl_data
      expect(response.status).to eq 201
    end
    
    it 'creates a new annotation from params from form' do
      post :create, :annotation => {:data => ttl_data}
      expect(response.status).to eq 201
    end

    it "renders 403 if Triannon::ExternalReferenceError raised during LdpWriter.create_anno" do
      err_msg = "some error during LdpWriter.create_anno"
      allow(Triannon::LdpWriter).to receive(:create_anno).and_raise(Triannon::ExternalReferenceError, err_msg)
      post :create, ttl_data
      expect(response.status).to eq 403
      expect(response.body).to eql err_msg
    end

    context 'HTTP Content-Type header' do

      shared_examples_for 'header matches data' do | header_mimetype, data, from_xxx_method_sym |
        it "#{header_mimetype} specified and provided" do
          gg = RDF::Graph.new
          gg.send(from_xxx_method_sym, data)
          allow(RDF::Graph).to receive(:new).and_return(gg)
          expect_any_instance_of(RDF::Graph).to receive(from_xxx_method_sym).at_least(:once).and_return(gg)
          request.headers["Content-Type"] = header_mimetype
          post :create, data
          expect(response.status).to eq 201
        end
      end
      shared_examples_for 'header does NOT match data' do | header_mimetype, data, from_xxx_method_sym |
        it "#{header_mimetype} specified and NOT provided" do
          gg = RDF::Graph.new
          allow(RDF::Graph).to receive(:new) {gg}
          expect_any_instance_of(RDF::Graph).to receive(from_xxx_method_sym).at_least(:once)
          allow_any_instance_of(Triannon::Annotation).to receive(:solr_save) # avoid spec error
          request.headers["Content-Type"] = header_mimetype
          post :create, data
          expect(response.status).to eq 400
        end
      end

      # turtle
      %w{application/x-turtle text/turtle}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.ttl"), :from_ttl
      }
      it_behaves_like 'header does NOT match data', 'application/x-turtle', Triannon.annotation_fixture("body-chars.json"), :from_ttl

      # rdfxml
      %w{application/rdf+xml text/rdf+xml text/rdf}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.rdf"), :from_rdfxml
      }
      it_behaves_like 'header does NOT match data', 'application/rdf+xml', Triannon.annotation_fixture("body-chars.json"), :from_rdfxml
      # xml specified (but is rdf xml)
      %w{application/xml text/xml application/x-xml}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.rdf"), :from_rdfxml
      }

      # json - must be tested differently due to using inline context substitution for jsonld
      let(:jsonld_data) { Triannon.annotation_fixture("body-chars.json") }
      it "jsonld specified and matches data" do
        g = RDF::Graph.new.from_jsonld jsonld_data
        allow(RDF::Graph).to receive(:new).and_return(g)
        expect(JSON::LD::API).to receive(:toRdf).and_return(g)
        request.headers["Content-Type"] = "application/ld+json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "jsonld specified and NOT provided" do
        expect_any_instance_of(Triannon::Annotation).to receive(:jsonld_to_graph).at_least(:once)
        allow_any_instance_of(Triannon::Annotation).to receive(:solr_save) # avoid spec error
        request.headers["Content-Type"] = "application/ld+json"
        post :create, ttl_data
        expect(response.status).to eq 400
      end
      # I couldn't get the three tests below to run cleanly in a loop
      it "application/json specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "application/json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "text/x-json specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "text/x-json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "application/jsonrequest specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "application/jsonrequest"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "unknown format gives 400" do
        request.headers["Content-Type"] = "application/foo"
        post :create, jsonld_data
        expect(response.status).to eq 400
      end
      it "unspecified Content-Type - tries to infer it" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect_any_instance_of(Triannon::Annotation).to receive(:jsonld_to_graph).and_return(gg)
        request.headers["Content-Type"] = nil
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
=begin
      context 'jsonld content' do
        context 'included in header' do
          it "honors oa generic uri" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "honors oa dated uri" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "honors iiif uri" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "ignores unrecognized uri (looks inline)" do
            fail "test to be implemented"
          end
        end # included in header
        context "NOT included in header" do
          it "oa generic uri inline" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "oa dated uri inline" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "iiif uri inline" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "assumes oa context when none specified inline" do
            # creates anno properly
            fail "test to be implemented"
          end
          it "raises 400 error when none specified inline and it doesn't parse for oa" do
            fail "test to be implemented"
          end
        end # NOT included in header
      end # jsonld context
=end      
    end # HTTP Content-Type header
  end # #create
  
  context '#show' do
    before(:each) do
      allow(Triannon::Annotation).to receive(:find).with('123').and_return(bookmark_anno)
      allow(Triannon::Annotation).to receive(:find).with('666').and_return(body_chars_anno)
    end
    context 'jsonld_context param' do
      shared_examples_for 'jsonld_context respected' do | jsonld_context, format |
        it 'calls correct method in Triannon::Annotation model' do
          if !format || format.length == 0
            format = "application/ld+json"
          end
          @request.accept = format
          model = double()
          allow(Triannon::Annotation).to receive(:find).and_return(model)
          case jsonld_context
            when "iiif", "IIIF"
              expect(model).to receive(:jsonld_iiif)
              get :show, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_iiif)
              get :show, id: body_chars_anno.id, jsonld_context: jsonld_context
            when "oa", "OA"
              expect(model).to receive(:jsonld_oa)
              get :show, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_oa)
              get :show, id: body_chars_anno.id, jsonld_context: jsonld_context
          end
        end
        it "response has correct context" do
          @request.accept = "application/ld+json"
          [bookmark_anno, body_chars_anno].each { |anno|  
            get :show, id: anno.id, jsonld_context: jsonld_context
            case jsonld_context
              when "iiif", "IIIF"
                expect(@response.body).to match(Triannon::JsonldContext::IIIF_CONTEXT_URL)
                expect(@response.body).to match(/"on":/)
              when "oa", "OA"
                expect(@response.body).to match(Triannon::JsonldContext::OA_CONTEXT_URL)
                expect(@response.body).to match(/"hasTarget":/)
            end
            expect(@response.content_type).to eql("application/ld+json")
            expect(@response.body).to match json_regex
            expect(@response.status).to eql(200)
          }
        end
      end
    
      context "iiif" do
        it_behaves_like 'jsonld_context respected', "iiif"
      end
      context "IIIF" do
        it_behaves_like 'jsonld_context respected', "IIIF"
      end
      context "oa" do
        it_behaves_like 'jsonld_context respected', "oa"
      end
      context "OA" do
        it_behaves_like 'jsonld_context respected', "OA"
      end
      it 'returns OA context jsonld when neither iiif or oa is in path' do
        @request.accept = "application/ld+json"
        get :show, id: bookmark_anno.id, jsonld_context: 'foo'
        expect(@response.body).to match(Triannon::JsonldContext::OA_CONTEXT_URL)
        expect(@response.body).to match(/"hasTarget":/)
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it 'returns OA context jsonld when context is missing in path' do
        @request.accept = "application/ld+json"
        get :show, id: bookmark_anno.id, jsonld_context: ''
        expect(@response.body).to match(Triannon::JsonldContext::OA_CONTEXT_URL)
        expect(@response.body).to match(/"hasTarget":/)
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      context 'pays attention to jsonld_context for all jsonld and json accept formats' do
        it_behaves_like 'jsonld_context respected', "iiif", "application/ld+json"
        it_behaves_like 'jsonld_context respected', "iiif", "application/json"
        it_behaves_like 'jsonld_context respected', "iiif", "text/x-json"
        it_behaves_like 'jsonld_context respected', "iiif", "application/jsonrequest"
        it_behaves_like 'jsonld_context respected', "iiif", ""
        it_behaves_like 'jsonld_context respected', "oa", "application/ld+json"
        it_behaves_like 'jsonld_context respected', "oa", "application/json"
        it_behaves_like 'jsonld_context respected', "oa", "text/x-json"
        it_behaves_like 'jsonld_context respected', "oa", "application/jsonrequest"
        it_behaves_like 'jsonld_context respected', "oa", ""
      end
      it 'ignores jsonld_context for formats other than jsonld and json' do
        ["application/x-turtle", "application/rdf+xml"].each { |mime_type|  
          @request.accept = mime_type
          [bookmark_anno, body_chars_anno].each { |anno|  
            get :show, id: anno.id, jsonld_context: 'iiif'
            expect(@response.body).not_to match(Triannon::JsonldContext::IIIF_CONTEXT_URL)
            expect(@response.body).not_to match(/"on":/)
            expect(@response.body).not_to match json_regex
            expect(@response.content_type).to eql(mime_type)
            expect(@response.status).to eql(200)
          }
        }
      end
    end
    
    context "response format" do
      shared_examples_for 'accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            @request.accept = mtype
            get :show, id: bookmark_anno.id
            expect(@response.content_type).to eql(mtype)
            expect(@response.body).to match(regex)
            expect(@response.status).to eql(200)
          end
        }
      end
      context "turtle" do
        # regex:  \Z is needed instead of $ due to \n in data)
        it_behaves_like 'accept header determines media type', ["text/turtle", "application/x-turtle"], /\.\Z/
      end
      context "rdfxml" do
        # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
        it_behaves_like 'accept header determines media type', ["application/rdf+xml", "text/rdf+xml", "text/rdf", "application/xml", "text/xml", "application/x-xml"], /\A<.+>\Z/m
      end
      context "json" do
        it_behaves_like 'accept header determines media type', ["application/ld+json", "application/json", "text/x-json", "application/jsonrequest"], json_regex
      end
      it "empty string gets json-ld" do
        @request.accept = ""
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "nil gets json-ld" do
        @request.accept = nil
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "*/* gets json-ld" do
        @request.accept = "*/*"
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "html uses view" do
        @request.accept = "text/html"
        get :show, id: bookmark_anno.id
        expect(response.content_type).to eql("text/html")
        expect(response.status).to eql(200)
        expect(response).to render_template(:show)
      end
      context 'multiple formats' do
        # rails will use them in order listed in the http accept header value.
        # also, "note that if browser is sending */* along with other values then Rails totally bails out and just returns Mime::HTML"
        #   http://blog.bigbinary.com/2010/11/23/mime-type-resolution-in-rails.html
        it 'uses first known format' do
          @request.accept = "application/ld+json, text/x-json, application/json"
          get :show, id: bookmark_anno.id
          expect(@response.content_type).to eql("application/ld+json")
          expect(@response.body).to match json_regex
          expect(@response.status).to eql(200)
        end
      end
    end # response format
    
  end # #show

  context '#destroy' do
    it "returns 204 status code for successful delete" do
      anno = Triannon::Annotation.new({:data => Triannon.annotation_fixture("body-chars.ttl")})
      anno_id = anno.save
      my_anno = Triannon::Annotation.find(anno_id)
      delete :destroy, :id => anno_id
      expect(response.status).to eq 204
    end
  end

end
