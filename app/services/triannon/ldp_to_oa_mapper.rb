module Triannon
  class LdpToOaMapper

    # maps an AnnotationLdp to an OA RDF::Graph
    def self.ldp_to_oa ldp_anno
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_bodies
      mapper.extract_targets
      mapper.oa_graph
    end

    attr_accessor :id, :oa_graph

    def initialize ldp_anno
      @ldp_anno = ldp_anno
      @ldp_anno_graph = ldp_anno.stripped_graph
      @oa_graph = RDF::Graph.new
    end

    def extract_base
      @ldp_anno_graph.each_statement do |stmnt|
        if stmnt.predicate == RDF.type && stmnt.object == RDF::OpenAnnotation.Annotation
          @id = stmnt.subject.to_s.split('/').last
          @root_uri = RDF::URI.new(Triannon.config[:triannon_base_url] + "/#{@id}")
          @oa_graph << [@root_uri, RDF.type, RDF::OpenAnnotation.Annotation]

        elsif stmnt.predicate == RDF::OpenAnnotation.motivatedBy
          @oa_graph << [@root_uri, stmnt.predicate, stmnt.object]
        end
      end
    end

    def extract_bodies
      @ldp_anno.body_uris.each { |body_uri|
        if !map_external_ref(body_uri, RDF::OpenAnnotation.hasBody) &&
            !map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody)
          map_specific_resource(body_uri, RDF::OpenAnnotation.hasBody)
        end
      }
    end

    def extract_targets
      @ldp_anno.target_uris.each { |target_uri| 
        if !map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)
          map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)
        end
      }
    end
    
    # if uri_obj is the subject of a Triannon.externalReference then add appropriate
    #  statements to @oa_graph and return true
    # @param [RDF::URI] uri_obj the object that may have RDF::Triannon.externalReference
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_external_ref uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF::Triannon.externalReference, nil]
      if solns.count > 0
        external_uri = solns.first.object
        @oa_graph << [@root_uri, predicate, external_uri]
        
        Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
          if stmt.subject == uri_obj && stmt.predicate != RDF::Triannon.externalReference
            @oa_graph << [external_uri, stmt.predicate, stmt.object]
          else
            # we should never get here for external references ...
          end
        }
        true
      else
        false
      end
    end
    
    # if uri_obj has a type of RDF::Content.ContentAsText, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may type RDF::Content.ContentAsText
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_content_as_text uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::Content.ContentAsText]
      if solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]
        
        Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
          if stmt.subject == uri_obj
            @oa_graph << [blank_node, stmt.predicate, stmt.object]
          else
            # it is a descendant statment - take as is
            @oa_graph << stmt
          end
        }
        true
      else
        false
      end
    end
    
    # if uri_obj has a type of RDF::OpenAnnotation.SpecificResource, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may have type RDF::OpenAnnotation.SpecificResource
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_specific_resource uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]
      if solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]
        
        Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
          if stmt.subject == uri_obj
            @oa_graph << [blank_node, stmt.predicate, stmt.object]
          else
            # it is a descendant statment - take as is
            @oa_graph << stmt
          end
        }
        true
      else
        false
      end
    end

  end

end
