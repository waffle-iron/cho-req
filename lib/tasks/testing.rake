# frozen_string_literal: true

namespace :cho do
  desc 'Creates a collection with many works'
  task :collection_test, [:length] => [:environment] do |_t, args|
    length = args.fetch(:length, 10).to_i
    collection = Collection.new
    collection.title = ['Collection of Empty Works']
    collection.description = ['Contains all the empty works used in the test']
    collection.keyword = ['collection-test']
    collection.apply_depositor_metadata('chouser@example.com')
    collection.visibility = 'open'
    collection.save

    report_file = File.open('public/collection_test.csv', 'w')
    report_file.write("count,time\n")
    (1..length).each do |count|
      i = Image.new
      i.title = ["Collection Test Work #{count}"]
      i.description = ['Empty work used for testing collections with many works']
      i.keyword = ['collection-test']
      i.apply_depositor_metadata('chouser@example.com')
      i.visibility = 'open'
      benchmark(report_file, count) do
        i.member_of_collections = [collection]
        i.save
      end
    end
    report_file.close
  end

  desc 'Creates a work with many small files'
  task :small_work, [:length] => [:environment] do |_t, args|
    length = args.fetch(:length, 10).to_i

    # Create a work
    work = Image.new
    work.title = ['Work with many small files']
    work.visibility = 'open'
    work.apply_depositor_metadata('chouser@example.com')
    work.save

    user = User.find_by(user_key: 'chouser@example.com')
    work_permissions = work.permissions.map(&:to_hash)

    report_file = File.open('public/small_file_test.csv', 'w')
    report_file.write("count,time\n")

    # Attach N files to the work (based off of AttachFilesToWorkJob)
    (1..length).each do |count|
      randomize_file
      benchmark(report_file, count) do
        file_set = FileSet.new
        actor = Hyrax::Actors::FileSetActor.new(file_set, user)
        actor.create_metadata(visibility: 'open')
        file_set.title = ["Small File #{count}"]
        file_set.label = "Small File #{count}"
        file_set.save
        Hydra::Works::AddFileToFileSet.call(file_set, File.open('spec/fixtures/small_random.bin', 'r'), :original_file)
        actor.attach_to_work(work)
        actor.file_set.permissions_attributes = work_permissions
      end
    end
    report_file.close
  end

  def randomize_file
    File.open('spec/fixtures/small_random.bin', 'a') do |file|
      file.truncate((file.size - 36))
      file.syswrite(SecureRandom.uuid)
    end
  end

  def benchmark(file, count)
    start = Time.now
    yield
    file.write("#{count},#{(Time.now - start)}\n")
  end
end
