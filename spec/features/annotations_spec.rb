require 'spec_helper'

vcr_options = { :cassette_name => "features_annotations" }
describe "viewing an annotation", type: :feature, :vcr => vcr_options do
  before(:each) do
    annotation = create_annotation('body-chars.json')
    visit "/annotations/annotations/#{annotation.id}"
  end

  it "has a title" do
    expect(page).to have_content "Annotation"
  end

  it "has the id/url" do
    expect(page).to have_content "http://example.org/annos/annotation/body-chars.json"
  end

  it "has the type" do
    expect(page).to have_content "http://www.w3.org/ns/oa#Annotation"
  end

  context "target" do
    it "single url" do
      expect(page).to have_content "http://purl.stanford.edu/kq131cs7229"
    end
    it "mult urls" do
      anno = create_annotation('mult-targets.json')
      visit "/annotations/annotations/#{anno.id}"
      expect(page).to have_content "http://purl.stanford.edu/kq131cs7229"
      expect(page).to have_content "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    end
  end

  context "bodies" do
    it "missing body" do
      anno = create_annotation('bookmark.json')
      visit "/annotations/annotations/#{anno.id}"
      expect(page).to have_content "no body for this annotation"
    end
    it "single body chars" do
      expect(page).to have_content "I love this!"
    end
    it "multiple bodies" do
      skip "to be implemented"
    end
  end

  context "has motivation" do
    it "single" do
      expect(page).to have_content "http://www.w3.org/ns/oa#commenting"
    end
    it "multiple" do
      anno = create_annotation('mult-motivations.json')
      visit "/annotations/annotations/#{anno.id}"
      expect(page).to have_content "http://www.w3.org/ns/oa#moderating"
      expect(page).to have_content "http://www.w3.org/ns/oa#tagging"
    end
  end

  def create_annotation f
    Triannon::Annotation.create data: annotation_fixture(f)
  end

  def annotation_fixture fixture
    File.read Triannon.fixture_path("annotations/#{fixture}")
  end
end
